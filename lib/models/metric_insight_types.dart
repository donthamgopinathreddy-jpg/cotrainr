enum MetricType { steps, water, calories, distance }

class InsightArgs {
  final MetricType t;
  final List<double> w;
  final double? goal;

  InsightArgs(this.t, this.w, {this.goal});
}
