import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para a máscara
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';

class NovoOrcamentoScreen extends StatefulWidget {
  const NovoOrcamentoScreen({super.key});

  @override
  State<NovoOrcamentoScreen> createState() => _NovoOrcamentoScreenState();
}

class _NovoOrcamentoScreenState extends State<NovoOrcamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();
  final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

  // --- DADOS DO CLIENTE ---
  final _clienteController = TextEditingController();
  final _localController = TextEditingController();
  final _contatoController = TextEditingController();
  final _dataController = TextEditingController();

  // --- ITENS SELECIONADOS ---
  List<Produto> _produtosDisponiveis = [];
  List<Map<String, dynamic>> _itensOrcamento = []; 
  Produto? _produtoSelecionado;
  final _qtdController = TextEditingController();

  // --- CUSTOS EXTRAS ---
  List<Map<String, dynamic>> _custosExtras = [];
  final _descCustoController = TextEditingController();
  final _valorCustoController = TextEditingController();

  // --- CACHÊ ---
  final _cacheController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  void _carregarProdutos() async {
    final data = await dbHelper.getProdutos();
    setState(() {
      _produtosDisponiveis = data.map((item) => Produto.fromMap(item)).toList();
    });
  }

  // --- CÁLCULOS MATEMÁTICOS ---
  double get _totalVendaItens => _itensOrcamento.fold(0.0, (sum, item) => sum + (item['total_venda'] as double));
  double get _totalLucroItens => _itensOrcamento.fold(0.0, (sum, item) => sum + (item['lucro_total'] as double));
  double get _totalCustosExtras => _custosExtras.fold(0.0, (sum, item) => sum + (item['valor'] as double));
  double get _valorCache {
    if (_cacheController.text.isEmpty) return 0.0;
    return double.tryParse(_cacheController.text.replaceAll(',', '.')) ?? 0.0;
  }
  double get _lucroLiquidoServico => (_totalLucroItens + _valorCache) - _totalCustosExtras;
  double get _valorFinalCliente => _totalVendaItens + _valorCache + _totalCustosExtras; 

  // --- AÇÕES UI ---

  void _adicionarItem() {
    if (_produtoSelecionado == null || _qtdController.text.isEmpty) return;

    int qtd = int.parse(_qtdController.text);
    if (qtd > _produtoSelecionado!.qtdEstoque) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Atenção: Estoque atual é de apenas ${_produtoSelecionado!.qtdEstoque} unidades!'), backgroundColor: Colors.orange),
      );
    }

    double totalVenda = qtd * _produtoSelecionado!.valorCliente;
    double lucroTotal = qtd * _produtoSelecionado!.lucroUnitario;

    setState(() {
      _itensOrcamento.add({
        'produto': _produtoSelecionado,
        'quantidade': qtd,
        'total_venda': totalVenda,
        'lucro_total': lucroTotal,
      });
      _produtoSelecionado = null;
      _qtdController.clear();
    });
  }

  void _adicionarCustoExtra() {
    if (_descCustoController.text.isEmpty || _valorCustoController.text.isEmpty) return;
    double valor = double.parse(_valorCustoController.text.replaceAll(',', '.'));

    setState(() {
      _custosExtras.add({
        'descricao': _descCustoController.text,
        'valor': valor,
      });
      _descCustoController.clear();
      _valorCustoController.clear();
    });
  }

  void _removerItem(int index) {
    setState(() { _itensOrcamento.removeAt(index); });
  }

  void _removerCusto(int index) {
    setState(() { _custosExtras.removeAt(index); });
  }

  // --- SALVAR E PDF ---
  Future<void> _salvarEGerarPDF() async {
    if (_clienteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha o nome do Cliente')));
      return;
    }

    final db = await dbHelper.database;

    // 1. Salvar Cabeçalho (Status PENDENTE)
    int orcamentoId = await db.insert('orcamentos', {
      'cliente': _clienteController.text,
      'local': _localController.text,
      'contato': _contatoController.text,
      'data_evento': _dataController.text,
      'cache_blaster': _valorCache,
      'total_custos_extras': _totalCustosExtras,
      'total_lucro_servico': _lucroLiquidoServico,
      'status': 'PENDENTE' // Baixa estoque, mas pode cancelar depois
    });

    // 2. Itens e Baixa de Estoque
    for (var item in _itensOrcamento) {
      Produto p = item['produto'];
      await db.insert('itens_orcamento', {
        'orcamento_id': orcamentoId,
        'produto_id': p.id,
        'quantidade': item['quantidade'],
        'valor_venda_total': item['total_venda'],
        'lucro_presumido_total': item['lucro_total'],
      });
      await db.rawUpdate('UPDATE produtos SET qtd_estoque = qtd_estoque - ? WHERE id = ?', [item['quantidade'], p.id]);
    }

    // 3. Gerar PDF
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
                    pw.Text('Data: ${_dataController.text}', style: pw.TextStyle(font: font, fontSize: 14)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Text('Cliente: ${_clienteController.text}', style: pw.TextStyle(font: font, fontSize: 18)),
              pw.Text('Local: ${_localController.text}', style: pw.TextStyle(font: font, fontSize: 14)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headers: ['Item / Descrição', 'Qtd', 'Valor Unit.', 'Total'],
                data: _itensOrcamento.map((item) {
                  Produto p = item['produto'];
                  return [
                    p.nome,
                    item['quantidade'].toString(),
                    currency.format(p.valorCliente),
                    currency.format(item['total_venda']),
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
                      pw.Text('Subtotal Itens: ${currency.format(_totalVendaItens)}', style: pw.TextStyle(font: font)),
                      pw.Text('Taxas / Logística / Extras: ${currency.format(_totalCustosExtras)}', style: pw.TextStyle(font: font)),
                      pw.Text('Serviço Técnico: ${currency.format(_valorCache)}', style: pw.TextStyle(font: font)),
                      pw.Divider(),
                      pw.Text(
                        'TOTAL: ${currency.format(_valorFinalCliente)}',
                        style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)
                      ),
                    ]
                  )
                ]
              ),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text('Orçamento válido por 15 dias.', style: pw.TextStyle(font: font, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    _carregarProdutos();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Orçamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- BLOCO 1 ---
              _buildTituloBloco('1. Dados do Evento'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextFormField(controller: _clienteController, decoration: const InputDecoration(labelText: 'Cliente')),
                      TextFormField(controller: _localController, decoration: const InputDecoration(labelText: 'Local')),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _contatoController, decoration: const InputDecoration(labelText: 'Contato'))),
                          const SizedBox(width: 10),
                          Expanded(
                            // AQUI ESTÁ A MÁSCARA DD/MM/AAAA
                            child: TextFormField(
                              controller: _dataController,
                              decoration: const InputDecoration(labelText: 'Data', hintText: 'DD/MM/AAAA'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10), // Limita tamanho
                                DataInputFormatter(), // Aplica a máscara
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- BLOCO 2 ---
              _buildTituloBloco('2. Descrição (Materiais)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<Produto>(
                        value: _produtoSelecionado,
                        hint: const Text('Selecione um Item'),
                        isExpanded: true, // Evita overflow no dropdown
                        items: _produtosDisponiveis.map((Produto item) {
                          return DropdownMenuItem<Produto>(
                            value: item,
                            child: Text(
                              '${item.nome} (${item.qtdEstoque})', 
                              overflow: TextOverflow.ellipsis // Corta texto longo
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _produtoSelecionado = val),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(controller: _qtdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade')),
                          ),
                          IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: _adicionarItem)
                        ],
                      ),
                      const Divider(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itensOrcamento.length,
                        itemBuilder: (context, index) {
                          final item = _itensOrcamento[index];
                          final prod = item['produto'] as Produto;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero, // Ganha espaço
                            title: Text('${prod.nome} (x${item['quantidade']})'),
                            subtitle: Text('Lucro Pres.: ${currency.format(item['lucro_total'])}', style: TextStyle(color: Colors.green[700])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currency.format(item['total_venda']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removerItem(index)),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('Total Venda: ${currency.format(_totalVendaItens)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          // CORREÇÃO DE OVERFLOW NO LUCRO
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Lucro Itens: ${currency.format(_totalLucroItens)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- BLOCO 3 ---
              _buildTituloBloco('3. Custos Extras'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: 2, child: TextFormField(controller: _descCustoController, decoration: const InputDecoration(labelText: 'Descrição'))),
                          const SizedBox(width: 10),
                          Expanded(flex: 1, child: TextFormField(controller: _valorCustoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor'))),
                          IconButton(icon: const Icon(Icons.add_circle, color: Colors.red, size: 32), onPressed: _adicionarCustoExtra),
                        ],
                      ),
                      const Divider(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _custosExtras.length,
                        itemBuilder: (context, index) {
                          final item = _custosExtras[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['descricao']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('- ${currency.format(item['valor'])}', style: const TextStyle(color: Colors.red)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => _removerCusto(index)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- BLOCO 4 ---
              _buildTituloBloco('4. Fechamento'),
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _cacheController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Seu Cachê (R\$)', fillColor: Colors.white, filled: true),
                        onChanged: (val) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      _buildLinhaResultado('Valor P/ Cliente:', _valorFinalCliente, cor: Colors.blue, tamanho: 18),
                      const SizedBox(height: 10),
                      
                      // LUCRO REAL (COM PROTEÇÃO DE OVERFLOW)
                      Container(
                        width: double.infinity, // Ocupa largura total
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text('SEU LUCRO LÍQUIDO REAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            // FITTED BOX PARA NÚMEROS GIGANTES
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currency.format(_lucroLiquidoServico),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Texto explicativo que quebra linha se precisar
                            Text(
                              '(${currency.format(_totalLucroItens)} itens + ${currency.format(_valorCache)} cachê - ${currency.format(_totalCustosExtras)} custos)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('SALVAR E GERAR PDF'),
                onPressed: _salvarEGerarPDF,
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTituloBloco(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
    );
  }
  
  Widget _buildLinhaResultado(String label, double valor, {Color cor = Colors.black, double tamanho = 16}) {
    // Row com Flexible para evitar overflow em telas pequenas
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: TextStyle(fontSize: tamanho, fontWeight: FontWeight.w500))),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(currency.format(valor), style: TextStyle(fontSize: tamanho, fontWeight: FontWeight.bold, color: cor)),
          ),
        ),
      ],
    );
  }
}

// --- CLASSE DA MÁSCARA DE DATA (DD/MM/AAAA) ---
class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      // Adiciona barra após o dia e mês, mas não se o usuário estiver apagando
      if (nonZeroIndex <= 2 && nonZeroIndex % 2 == 0 && text.length != 2) {
        buffer.write('/'); 
      } else if (nonZeroIndex <= 4 && nonZeroIndex % 4 == 0 && text.length != 5 && i > 2) {
        // Correção de lógica simples para barra do ano
      }
    }
    
    // Lógica simplificada e robusta para DD/MM/AAAA
    var str = text.replaceAll('/', '');
    var finalString = "";
    
    for (int i = 0; i < str.length; i++) {
      finalString += str[i];
      if ((i == 1 || i == 3) && i != str.length - 1) {
        finalString += "/";
      }
    }

    return newValue.copyWith(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}