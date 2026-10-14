import 'package:flutter/widgets.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(child:Text("Calendario"));
  }
}