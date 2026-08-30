import 'package:aqua_steward/core/extensions/l10n_extensions.dart';
import 'package:aqua_steward/core/extensions/to_clean_string.dart';
import 'package:aqua_steward/core/theme/app_border.dart';
import 'package:aqua_steward/core/theme/app_color.dart';
import 'package:aqua_steward/core/theme/app_padding.dart';
import 'package:aqua_steward/core/theme/app_sizedbox.dart';
import 'package:aqua_steward/core/widgets/container_formart.dart';
import 'package:aqua_steward/core/widgets/filter_chip_format.dart';
import 'package:aqua_steward/core/widgets/linea_chart.dart';
import 'package:aqua_steward/core/widgets/text_format.dart';
import 'package:aqua_steward/features/reading/presentation/widgets/circular_progress_parameters.dart';
import 'package:aqua_steward/features/reading/presentation/widgets/deposit_level.dart';
import 'package:aqua_steward/features/reading/presentation/widgets/state_parameters.dart';
import 'package:flutter/material.dart';

class DepositCard extends StatefulWidget {
  final Map<String, dynamic> depositData;
  final Widget menuWidget;

  const DepositCard({
    super.key,
    required this.depositData,
    required this.menuWidget,
  });

  @override
  State<DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends State<DepositCard> {
  int? _selectedParameterIndex;
  String _selectedFilter = "Dia";

  static const List<Color> _sensorColors = [
    AppColor.parameterAqua,
    AppColor.parameterPH,
    AppColor.parameterTurbidity,
  ];

  bool _isSensorActive(dynamic sensors, int index) {
    if (sensors == null || sensors is! List || index >= sensors.length) {
      return true;
    }
    final sensor = sensors[index];
    return (sensor is Map ? sensor["state"] : sensor.state) ?? true;
  }

  Widget _buildSensorItem({required int index, required Widget child}) {
    final isSelected = _selectedParameterIndex == index;
    return InkWell(
      borderRadius: AppBorder.all8,
      onTap: () {
        setState(() {
          _selectedParameterIndex = isSelected ? null : index;
        });
      },
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: _sensorColors[index], width: 2.0),
                borderRadius: AppBorder.all8,
              )
            : null,
        padding: AppPadding.all8,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depositData = widget.depositData;
    final sensors = depositData["sensors"];

    final double inputLevel = (depositData["inputLevel"] as num).toDouble();
    final double inputPh = (depositData["inputPh"] as num).toDouble();
    final double inputTurbidity = (depositData["inputTurbidity"] as num)
        .toDouble();

    final double peakLevel = (depositData["peakLevel"] as num).toDouble();
    final double peakPh = (depositData["peakPh"] as num).toDouble();
    final double peakTurbidity = (depositData["peakTurbidity"] as num)
        .toDouble();

    final List<String> parametersLabel = [
      context.l10n.sensor_nivel,
      context.l10n.sensor_ph,
      context.l10n.sensor_turbidez,
    ];
    final List<double> peakParameters = [peakLevel, peakPh, peakTurbidity];
    final List<double> inputParameters = [inputLevel, inputPh, inputTurbidity];
    final List<String> unitParameters = ["%", "pH", "NTU"];

    final bool isLevelActive = _isSensorActive(sensors, 0);
    final bool isPhActive = _isSensorActive(sensors, 1);
    final bool isTurbidityActive = _isSensorActive(sensors, 2);
    final bool hasSecondary = isPhActive || isTurbidityActive;

    Widget buildCircular(int index) => CircularProgressParameters(
      index: index,
      peakParameters: peakParameters,
      imputParameters: inputParameters,
      parametersLabel: parametersLabel,
      unit: unitParameters,
      depositData: depositData,
    );

    return ContainerFormat(
      children: [
        // Header de tarjeta
        Padding(
          padding: AppPadding.symmetric0_8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextFormat(
                text: depositData["name"],
                context: context,
                type: "titleSmall",
              ),
              widget.menuWidget,
            ],
          ),
        ),

        // Sensores
        Padding(
          padding: AppPadding.symmetric0_8,
          child: isLevelActive && hasSecondary
              // Caso 1: Nivel (Izq) + Secundarios (Der)
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildSensorItem(
                          index: 0,
                          child: DepositLevel(level: inputLevel),
                        ),
                      ),
                      AppSizedBox.width8,
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 1; i < 3; i++)
                              if (_isSensorActive(sensors, i))
                                _buildSensorItem(
                                  index: i,
                                  child: buildCircular(i),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : isLevelActive
              // Caso 2: Solo nivel
              ? Center(
                  child: _buildSensorItem(
                    index: 0,
                    child: DepositLevel(level: inputLevel),
                  ),
                )
              // Caso 3: Solo secundarios
              : Row(
                  children: [
                    for (int i = 1; i < 3; i++)
                      if (_isSensorActive(sensors, i))
                        Expanded(
                          child: _buildSensorItem(
                            index: i,
                            child: buildCircular(i),
                          ),
                        ),
                  ],
                ),
        ),

        // Detalle expandible
        if (_selectedParameterIndex != null &&
            _isSensorActive(sensors, _selectedParameterIndex!)) ...[
          AppSizedBox.height12,
          _buildParameterDetail(
            context,
            index: _selectedParameterIndex!,
            currentValue: inputParameters[_selectedParameterIndex!],
            peakValue: peakParameters[_selectedParameterIndex!],
          ),
        ],
      ],
    );
  }

  Widget _buildParameterDetail(
    BuildContext context, {
    required int index,
    required double currentValue,
    required double peakValue,
  }) {
    final depositData = widget.depositData;
    final sensorType = const ["HC-SR04", "PH-4502C", "TS300B"][index];
    final unit = const ["%", "pH", "NTU"][index];
    final color = _sensorColors[index];
    final maxY = index == 2 ? peakValue : const [100.0, 14.0, 0.0][index];

    double? minVal;
    double? maxVal;
    final sensors = depositData["sensors"];
    if (sensors is List) {
      for (final s in sensors) {
        final type = s is Map ? s["type"] : s.type;
        if (type == sensorType) {
          minVal = s is Map ? (s["min_value"] as num?)?.toDouble() : s.minValue;
          maxVal = s is Map ? (s["max_value"] as num?)?.toDouble() : s.maxValue;
          break;
        }
      }
    }

    final rangeMin = minVal?.toCleanString();
    final rangeMax = maxVal?.toCleanString();
    final stateText = StateParameters.show(context, currentValue, unit);

    final filters = [
      ("Dia", context.l10n.detalles_diario),
      ("Semana", context.l10n.detalles_semanal),
      ("Mes", context.l10n.detalles_mensual),
    ];

    return Padding(
      padding: AppPadding.symmetric0_8,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ContainerFormat(
                  children: [
                    if (unit != "%") ...[
                      TextFormat(
                        text: context.l10n.dashboard_estado,
                        context: context,
                        type: "body",
                      ),
                      TextFormat(
                        text: stateText,
                        context: context,
                        type: "titleSmall",
                      ),
                    ] else ...[
                      TextFormat(
                        text: "${context.l10n.detalles_capacidad}:",
                        context: context,
                        type: "body",
                      ),
                      TextFormat(
                        text: "${peakValue.toCleanString()} L",
                        context: context,
                        type: "titleSmall",
                      ),
                    ],
                  ],
                ),
              ),
              AppSizedBox.width8,
              Expanded(
                child: ContainerFormat(
                  children: [
                    TextFormat(
                      alignCenter: true,
                      text: "${context.l10n.comun_umbrales}:",
                      context: context,
                      type: "body",
                    ),
                    TextFormat(
                      alignCenter: true,
                      text: unit != "NTU"
                          ? "${rangeMin ?? ""} - ${rangeMax ?? ""} $unit"
                          : "${rangeMax ?? ""} $unit",
                      context: context,
                      type: "titleSmall",
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSizedBox.height12,

          // Filtros
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < filters.length; i++) ...[
                if (i > 0) AppSizedBox.width8,
                FilterChipFormat(
                  label: filters[i].$2,
                  isSelected: _selectedFilter == filters[i].$1,
                  onSelected: (_) {
                    if (_selectedFilter != filters[i].$1) {
                      setState(() => _selectedFilter = filters[i].$1);
                    }
                  },
                ),
              ],
            ],
          ),
          AppSizedBox.height12,

          // Gráfico
          LineaChart(
            key: ValueKey("$sensorType-$_selectedFilter"),
            depositId: depositData["id"] ?? "",
            sensorType: sensorType,
            color: color,
            maxY: maxY,
            unit: unit,
            selectedFilter: _selectedFilter,
          ),
        ],
      ),
    );
  }
}
