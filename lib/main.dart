import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart'; // PACOTE GRÁFICOS
import 'database/database_helper.dart';
import 'screens/inventario_screen.dart';
import 'screens/novo_orcamento_screen.dart';
import 'screens/historico_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const BlasterManagerApp());
}

class BlasterManagerApp extends StatelessWidget {
  const BlasterManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blaster Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final dbHelper = DatabaseHelper();
  final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
  
  // Variáveis do Dashboard
  double lucroTotal = 0.0;
  int aprovados = 0;
  int cancelados = 0;
  int pendentes = 0;
  List<Map<String, dynamic>> topProdutos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // Recarrega os dados toda vez que a tela aparece (ex: voltou do histórico)
  void _carregarDados() async {
    setState(() => isLoading = true);
    final dados = await dbHelper.getDashboardData();
    
    // Processa contagem de status
    int ap = 0, can = 0, pen = 0;
    List<Map<String, dynamic>> statusList = dados['statusCounts'];
    for (var s in statusList) {
      if (s['status'] == 'APROVADO') ap = s['qtd'];
      if (s['status'] == 'CANCELADO') can = s['qtd'];
      if (s['status'] == 'PENDENTE') pen = s['qtd'];
    }

    setState(() {
      lucroTotal = dados['lucroTotal'];
      topProdutos = dados['topProdutos'];
      aprovados = ap;
      cancelados = can;
      pendentes = pen;
      isLoading = false;
    });
  }

  // Função de Backup
  void _fazerBackup() async {
    await dbHelper.exportarBackup();
  }

  // Função de Restaurar
  void _restaurarBackup() async {
    bool sucesso = await dbHelper.restaurarBackup();
    if (sucesso) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados restaurados com sucesso! Reiniciando dashboard...'), backgroundColor: Colors.green)
        );
      }
      _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Controle'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'backup') _fazerBackup();
              if (value == 'restaurar') _restaurarBackup();
              if (value == 'atualizar') _carregarDados();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(value: 'atualizar', child: Row(children: [Icon(Icons.refresh, color: Colors.blue), SizedBox(width: 10), Text('Atualizar Dados')])),
                const PopupMenuItem(value: 'backup', child: Row(children: [Icon(Icons.cloud_upload, color: Colors.green), SizedBox(width: 10), Text('Fazer Backup (Salvar)')])),
                const PopupMenuItem(value: 'restaurar', child: Row(children: [Icon(Icons.cloud_download, color: Colors.orange), SizedBox(width: 10), Text('Restaurar Backup')])),
              ];
            },
          ),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async => _carregarDados(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. CARD DE LUCRO TOTAL
                  Card(
                    elevation: 4,
                    color: Colors.deepOrange,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('LUCRO LÍQUIDO ACUMULADO', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(currency.format(lucroTotal), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          ),
                          const Text('(Apenas shows confirmados)', style: TextStyle(color: Colors.white30, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. GRÁFICO DE PIZZA (RESUMO DE SHOWS)
                  if (aprovados + cancelados + pendentes > 0)
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(color: Colors.green, value: aprovados.toDouble(), title: '$aprovados', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  PieChartSectionData(color: Colors.orange, value: pendentes.toDouble(), title: '$pendentes', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  PieChartSectionData(color: Colors.red, value: cancelados.toDouble(), title: '$cancelados', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                                centerSpaceRadius: 30,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 5), Text("Fechados")]),
                              SizedBox(height: 5),
                              Row(children: [Icon(Icons.circle, color: Colors.orange, size: 12), SizedBox(width: 5), Text("Pendentes")]),
                              SizedBox(height: 5),
                              Row(children: [Icon(Icons.circle, color: Colors.red, size: 12), SizedBox(width: 5), Text("Perdidos")]),
                            ],
                          )
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  const Text("Top 5 Materiais Mais Gastos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  // 3. LISTA TOP PRODUTOS
                  topProdutos.isEmpty 
                    ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("Sem dados de vendas ainda.", textAlign: TextAlign.center)))
                    : Column(
                        children: topProdutos.map((prod) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.bar_chart, color: Colors.deepOrange),
                              title: Text(prod['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: Text("${prod['qtd_total']} un", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 4. MENU DE NAVEGAÇÃO
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.5, // Botões mais achatados
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Novo\nOrçamento'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NovoOrcamentoScreen())).then((_) => _carregarDados()),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.history_edu),
                        label: const Text('Histórico\n& Agenda'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoricoScreen())).then((_) => _carregarDados()),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.inventory_2),
                        label: const Text('Banco de\nDados'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventarioScreen())),
                      ),
                      // Botão extra se quiser futuro (ex: Clientes)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.backup),
                        label: const Text('Backup\nRápido'),
                        onPressed: _fazerBackup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}