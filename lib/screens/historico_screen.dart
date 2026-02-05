import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../database/database_helper.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final dbHelper = DatabaseHelper();
  final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  
  List<Map<String, dynamic>> _listaOrcamentos = [];
  
  // Mapa para armazenar os checklists de cada orçamento carregado na tela
  // Chave: ID do Orçamento, Valor: Lista de Itens
  Map<int, List<Map<String, dynamic>>> _checklistsPorOrcamento = {};

  // Controladores para adicionar novo item ao checklist
  final _checkItemController = TextEditingController();
  final _checkQtdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  void _carregarHistorico() async {
    final db = await dbHelper.database;
    final data = await db.query('orcamentos', orderBy: 'id DESC');
    
    setState(() {
      _listaOrcamentos = data;
    });

    // Carrega os checklists de todos os orçamentos listados
    for (var orc in data) {
      // CORREÇÃO AQUI: Adicionado "as int" para garantir o tipo
      if (orc['id'] != null) {
        _carregarChecklistUnico(orc['id'] as int);
      }
    }
  }

  Future<void> _carregarChecklistUnico(int orcamentoId) async {
    final itens = await dbHelper.getChecklist(orcamentoId);
    setState(() {
      _checklistsPorOrcamento[orcamentoId] = itens;
    });
  }

  // --- LÓGICA DO CHECKLIST ---
  void _adicionarItemChecklist(int orcamentoId) async {
    if (_checkItemController.text.isEmpty || _checkQtdController.text.isEmpty) return;

    await dbHelper.insertChecklistItem({
      'orcamento_id': orcamentoId,
      'item_nome': _checkItemController.text,
      'quantidade': int.parse(_checkQtdController.text),
      'feito': 0 // Começa desmarcado
    });

    _checkItemController.clear();
    _checkQtdController.clear();
    
    // Atualiza a lista visualmente
    _carregarChecklistUnico(orcamentoId);
  }

  void _toggleCheckBox(int itemId, int orcamentoId, int statusAtual) async {
    int novoStatus = statusAtual == 0 ? 1 : 0;
    await dbHelper.toggleChecklistItem(itemId, novoStatus);
    _carregarChecklistUnico(orcamentoId);
  }

  void _deletarItemChecklist(int itemId, int orcamentoId) async {
    await dbHelper.deleteChecklistItem(itemId);
    _carregarChecklistUnico(orcamentoId);
  }

  // --- AGENDA / CALENDAR ---
  Future<void> _adicionarAgenda(Map<String, dynamic> item) async {
    try {
      final format = DateFormat("dd/MM/yyyy");
      final DateTime dataEvento = format.parse(item['data_evento']);

      final Event event = Event(
        title: 'Show Pirotecnia - ${item['cliente']}',
        description: 'Local: ${item['local']}\nContato: ${item['contato']}\nLucro Previsto: ${currency.format(item['total_lucro_servico'])}',
        location: item['local'],
        startDate: dataEvento,
        endDate: dataEvento.add(const Duration(hours: 2)),
        allDay: true,
      );

      bool sucesso = await Add2Calendar.addEvent2Cal(event);
      if (!sucesso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir a agenda.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro de data: $e')));
      }
    }
  }

  // --- STATUS VENDA ---
  Future<void> _alterarStatusVenda(int id, String novoStatus) async {
    final db = await dbHelper.database;
    
    if (novoStatus == 'CANCELADO') {
      final List<Map<String, dynamic>> itens = await db.query(
        'itens_orcamento',
        where: 'orcamento_id = ?',
        whereArgs: [id],
      );

      for (var item in itens) {
        await db.rawUpdate(
          'UPDATE produtos SET qtd_estoque = qtd_estoque + ? WHERE id = ?',
          [item['quantidade'], item['produto_id']]
        );
      }
    }

    await db.update('orcamentos', {'status': novoStatus}, where: 'id = ?', whereArgs: [id]);

    if (mounted) {
      String msg = novoStatus == 'APROVADO' ? 'Venda Confirmada!' : 'Venda Cancelada. Itens estornados.';
      Color cor = novoStatus == 'APROVADO' ? Colors.green : Colors.red;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
    }

    _carregarHistorico();
  }

  void _deletarOrcamento(int id) async {
    final db = await dbHelper.database;
    await db.delete('orcamentos', where: 'id = ?', whereArgs: [id]);
    _carregarHistorico(); 
  }

  // --- PDF ---
  Future<void> _gerarPDFNovamente(Map<String, dynamic> orcamento) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> itens = await db.rawQuery('''
      SELECT i.*, p.nome, p.valor_cliente 
      FROM itens_orcamento i
      INNER JOIN produtos p ON i.produto_id = p.id
      WHERE i.orcamento_id = ?
    ''', [orcamento['id']]);

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ORÇAMENTO DE PIROTECNIA', style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Data: ${orcamento['data_evento']}', style: pw.TextStyle(font: font, fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('Cliente: ${orcamento['cliente']}', style: pw.TextStyle(font: font, fontSize: 18)),
              pw.Text('Local: ${orcamento['local']}', style: pw.TextStyle(font: font, fontSize: 14)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headers: ['Item / Descrição', 'Qtd', 'Valor Unit.', 'Total'],
                data: itens.map((item) {
                  return [
                    item['nome'],
                    item['quantidade'].toString(),
                    currency.format(item['valor_cliente']),
                    currency.format(item['valor_venda_total']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font),
                cellStyle: pw.TextStyle(font: font),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Taxas / Logística / Extras: ${currency.format(orcamento['total_custos_extras'])}', style: pw.TextStyle(font: font)),
                      pw.Text('Serviço Técnico: ${currency.format(orcamento['cache_blaster'])}', style: pw.TextStyle(font: font)),
                      pw.Divider(),
                      pw.Text(
                        'TOTAL: ${currency.format(
                          itens.fold(0.0, (sum, i) => sum + (i['valor_venda_total'] as double)) + 
                          (orcamento['total_custos_extras'] as double) + 
                          (orcamento['cache_blaster'] as double)
                        )}',
                        style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)
                      ),
                    ]
                  )
                ]
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Orçamentos')),
      body: _listaOrcamentos.isEmpty
          ? const Center(child: Text('Nenhum orçamento salvo ainda.'))
          : ListView.builder(
              itemCount: _listaOrcamentos.length,
              itemBuilder: (context, index) {
                final item = _listaOrcamentos[index];
                final status = item['status'] ?? 'PENDENTE';
                // CORREÇÃO AQUI: Casting explicito para evitar erro futuro
                final int orcId = item['id'] as int;
                
                Color corStatus;
                if (status == 'APROVADO') {
                  corStatus = Colors.green;
                } else if (status == 'CANCELADO') {
                  corStatus = Colors.red[100]!;
                } else {
                  corStatus = Colors.orange[100]!;
                }

                // Pega a lista de checklist desse orçamento (ou lista vazia se null)
                List<Map<String, dynamic>> checklistAtual = _checklistsPorOrcamento[orcId] ?? [];

                return Card(
                  color: status == 'CANCELADO' ? Colors.red[50] : Colors.white,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: status == 'APROVADO' ? Colors.green : Colors.deepOrange,
                      child: Icon(status == 'APROVADO' ? Icons.check : Icons.description, color: Colors.white),
                    ),
                    title: Text(item['cliente'], style: TextStyle(fontWeight: FontWeight.bold, decoration: status == 'CANCELADO' ? TextDecoration.lineThrough : null)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['data_evento']} - ${item['local']}'),
                        Row(
                          children: [
                             Flexible(
                               child: FittedBox(
                                 fit: BoxFit.scaleDown,
                                 child: Text(
                                  'Lucro: ${currency.format(item['total_lucro_servico'])}', 
                                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                                 ),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(color: corStatus.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                               child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'APROVADO' ? Colors.green : Colors.black87)),
                             )
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. AÇÕES DE STATUS
                            if (status == 'PENDENTE') 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.close),
                                    label: const Text('Não Fechou'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => _alterarStatusVenda(orcId, 'CANCELADO'),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text('Confirmar'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () => _alterarStatusVenda(orcId, 'APROVADO'),
                                  ),
                                ],
                              ),
                            
                            if (status == 'CANCELADO')
                              const Center(child: Text('Venda cancelada e estoque estornado.', style: TextStyle(color: Colors.red))),

                            // 2. SE APROVADO: MOSTRA AGENDA E CHECKLIST OPERACIONAL
                            if (status == 'APROVADO')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.green[50],
                                    child: const Center(child: Text('Venda Confirmada!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  // Botão Agenda
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                                    icon: const Icon(Icons.calendar_month),
                                    label: const Text('Adicionar à Agenda'),
                                    onPressed: () => _adicionarAgenda(item),
                                  ),
                                  
                                  const Divider(thickness: 2),
                                  const Text('📋 Lista de Materiais Operacionais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 5),
                                  
                                  // INPUT PARA NOVO ITEM
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _checkItemController,
                                          decoration: const InputDecoration(hintText: 'Item (Ex: Maleta)', isDense: true),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: _checkQtdController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(hintText: 'Qtd', isDense: true),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_box, color: Colors.blue),
                                        onPressed: () => _adicionarItemChecklist(orcId),
                                      )
                                    ],
                                  ),
                                  
                                  // LISTA DE ITENS DO CHECKLIST
                                  checklistAtual.isEmpty 
                                    ? const Padding(padding: EdgeInsets.all(8.0), child: Text('Nenhum equipamento listado.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
                                    : ListView.builder(
                                        shrinkWrap: true, // Importante dentro de Column
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: checklistAtual.length,
                                        itemBuilder: (ctx, idx) {
                                          final checkItem = checklistAtual[idx];
                                          // Correção de tipo aqui também
                                          final int checkId = checkItem['id'] as int;
                                          final int feitoStatus = checkItem['feito'] as int;
                                          final bool isChecked = feitoStatus == 1;

                                          return ListTile(
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            leading: Checkbox(
                                              value: isChecked,
                                              onChanged: (val) => _toggleCheckBox(checkId, orcId, feitoStatus),
                                            ),
                                            title: Text(
                                              '${checkItem['item_nome']} (x${checkItem['quantidade']})',
                                              style: TextStyle(
                                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                                color: isChecked ? Colors.grey : Colors.black
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                              onPressed: () => _deletarItemChecklist(checkId, orcId),
                                            ),
                                          );
                                        }
                                      ),
                                ],
                              ),

                            const Divider(),
                            // 3. AÇÕES DE RODAPÉ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.print),
                                  label: const Text('Reimprimir'),
                                  onPressed: () => _gerarPDFNovamente(item),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_forever, color: Colors.grey),
                                  label: const Text('Apagar'),
                                  onPressed: () => _deletarOrcamento(orcId),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}