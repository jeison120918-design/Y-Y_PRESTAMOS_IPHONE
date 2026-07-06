import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/cliente.dart';
import '../models/prestamo.dart';
import '../utils/formato.dart';
import '../utils/generador_cuotas.dart';
import '../utils/calculadora_penalidad.dart';
import '../main.dart';

class PrestamoForm extends StatefulWidget {
  final int? clienteIdDefault;
  const PrestamoForm({super.key, this.clienteIdDefault});

  @override
  State<PrestamoForm> createState() => _PrestamoFormState();
}

class _PrestamoFormState extends State<PrestamoForm> {
  final _form = GlobalKey<FormState>();
  final _capital = TextEditingController();
  final _interes = TextEditingController(text: '20');
  final _cuotas = TextEditingController(text: '30');
  final _penalidad = TextEditingController(text: '50');
  final ValueNotifier<int> _resumenTick = ValueNotifier<int>(0);

  String _modalidad = 'diario';
  DateTime _fechaInicio = DateTime.now();
  int? _clienteSel;
  List<Cliente> _clientes = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _clienteSel = widget.clienteIdDefault;
    for (final ctrl in [_capital, _interes, _cuotas, _penalidad]) {
      ctrl.addListener(_notificarResumen);
    }
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    _clientes = await DBHelper().getClientes();
    if (_clienteSel == null && _clientes.isNotEmpty) {
      _clienteSel = _clientes.first.id;
    }
    if (mounted) setState(() {});
  }

  void _notificarResumen() {
    _resumenTick.value++;
  }

  double get _capitalNum => double.tryParse(_capital.text) ?? 0;
  double get _interesNum => double.tryParse(_interes.text) ?? 0;
  int get _cuotasNum => int.tryParse(_cuotas.text) ?? 0;
  double get _penalidadNum => double.tryParse(_penalidad.text) ?? 0;
  double get _montoTotal => _capitalNum + (_capitalNum * _interesNum / 100);
  double get _cuotaMonto => _cuotasNum > 0 ? _montoTotal / _cuotasNum : 0;

  String get _textoPenalidadHelper {
    final porDia = penalidadPorDia(_modalidad, _penalidadNum);
    switch (_modalidad) {
      case 'diario':
        return 'Se cobra ${formatoMoneda(porDia)} por cada dia de retraso.';
      case 'semanal':
        return 'La penalidad semanal se prorratea por dia: '
            '${formatoMoneda(porDia)} por dia. '
            'Si el cliente paga antes de la semana, solo se cobra la fraccion.';
      case 'quincenal':
        return 'La penalidad quincenal (15 dias) se prorratea por dia: '
            '${formatoMoneda(porDia)} por dia. '
            'Si paga antes de los 15 dias, solo se cobra la fraccion.';
      case 'mensual':
        return 'La penalidad mensual se prorratea por dia: '
            '${formatoMoneda(porDia)} por dia. '
            'Si paga antes del mes, solo se cobra la fraccion.';
      default:
        return '';
    }
  }

  Future<void> _seleccionarFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f != null) setState(() => _fechaInicio = f);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_clienteSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Debes crear un cliente antes de registrar prestamos.')));
      return;
    }
    setState(() => _guardando = true);

    final p = Prestamo(
      clienteId: _clienteSel!,
      capital: _capitalNum,
      tasaInteres: _interesNum,
      montoTotal: _montoTotal,
      modalidad: _modalidad,
      numCuotas: _cuotasNum,
      fechaInicio:
          "${_fechaInicio.year.toString().padLeft(4, '0')}-${_fechaInicio.month.toString().padLeft(2, '0')}-${_fechaInicio.day.toString().padLeft(2, '0')}",
      montoPenalidad: _penalidadNum,
      estado: 'activo',
    );
    final id = await DBHelper().insertPrestamo(p);
    final cuotas = generarCuotas(
      prestamoId: id,
      montoTotal: _montoTotal,
      numCuotas: _cuotasNum,
      modalidad: _modalidad,
      fechaInicio: _fechaInicio,
    );
    await DBHelper().insertCuotasBatch(cuotas);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _capital.dispose();
    _interes.dispose();
    _cuotas.dispose();
    _penalidad.dispose();
    _resumenTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Prestamo')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              value: _clienteSel,
              decoration: const InputDecoration(
                labelText: 'Cliente *',
                prefixIcon: Icon(Icons.person),
              ),
              items: _clientes
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                  .toList(),
              onChanged: (v) => setState(() => _clienteSel = v),
              validator: (v) => v == null ? 'Selecciona un cliente' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capital,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Capital prestado (RD\$) *',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? 'Capital invalido'
                  : null,
              
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _interes,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tasa de interes (%) *',
                prefixIcon: Icon(Icons.percent),
              ),
              validator: (v) =>
                  (double.tryParse(v ?? '') == null) ? 'Tasa invalida' : null,
              
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _modalidad,
              decoration: const InputDecoration(
                labelText: 'Modalidad de pago *',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'diario', child: Text('Diario')),
                DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                DropdownMenuItem(
                    value: 'quincenal',
                    child: Text('Quincenal (cada 15 dias)')),
                DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
              ],
              onChanged: (v) {
                setState(() => _modalidad = v ?? 'diario');
                _notificarResumen();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cuotas,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de cuotas *',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Cuotas invalidas' : null,
              
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<int>(
              valueListenable: _resumenTick,
              builder: (_, __, ___) => TextFormField(
                controller: _penalidad,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Penalidad por periodo (RD\$)',
                  prefixIcon: const Icon(Icons.gavel),
                  helperText: _textoPenalidadHelper,
                  helperMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AndryPrestamosApp.azulSuperficieAlt,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _seleccionarFecha,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AndryPrestamosApp.azulPrincipal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fecha de inicio',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                            Text(formatoFecha(_fechaInicio),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white60),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Resumen
            ValueListenableBuilder<int>(
              valueListenable: _resumenTick,
              builder: (_, __, ___) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AndryPrestamosApp.azulSuperficie,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AndryPrestamosApp.verdePrincipal),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.calculate,
                            color: AndryPrestamosApp.verdePrincipal),
                        SizedBox(width: 8),
                        Text('RESUMEN DEL PRESTAMO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AndryPrestamosApp.verdeClaro,
                            )),
                      ],
                    ),
                    const Divider(),
                    _line('Capital:', formatoMoneda(_capitalNum)),
                    _line('Interes:', '${_interesNum.toStringAsFixed(2)}%'),
                    _line('Monto total:', formatoMoneda(_montoTotal),
                        destacar: true),
                    _line('Cuota fija:', formatoMoneda(_cuotaMonto)),
                    _line('Modalidad:', modalidadLabel(_modalidad)),
                    if (_penalidadNum > 0)
                      _line(
                          'Penalidad diaria:',
                          formatoMoneda(
                              penalidadPorDia(_modalidad, _penalidadNum))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.save),
              label: Text(_guardando
                  ? 'Guardando...'
                  : 'Guardar prestamo y generar cuotas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool destacar = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: destacar ? FontWeight.bold : FontWeight.normal,
                  fontSize: destacar ? 14 : 13,
                )),
            Text(b,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: destacar ? 15 : 13,
                  color: destacar ? AndryPrestamosApp.dorado : Colors.white,
                )),
          ],
        ),
      );
}
