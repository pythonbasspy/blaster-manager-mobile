import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'blaster_manager_v3.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE produtos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        categoria TEXT,
        qtd_estoque INTEGER DEFAULT 0,
        valor_real REAL NOT NULL,
        valor_cliente REAL NOT NULL,
        lucro_unitario REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orcamentos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT,
        local TEXT,
        contato TEXT,
        data_evento TEXT,
        cache_blaster REAL,
        total_custos_extras REAL,
        total_lucro_servico REAL,
        status TEXT DEFAULT 'PENDENTE' 
      )
    ''');
    
    await db.execute('''
      CREATE TABLE itens_orcamento(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orcamento_id INTEGER,
        produto_id INTEGER,
        quantidade INTEGER,
        valor_venda_total REAL,
        lucro_presumido_total REAL,
        FOREIGN KEY(orcamento_id) REFERENCES orcamentos(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_operacional(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orcamento_id INTEGER,
        item_nome TEXT,
        quantidade INTEGER,
        feito INTEGER DEFAULT 0,
        FOREIGN KEY(orcamento_id) REFERENCES orcamentos(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- CRUD BÁSICO (Mantido igual) ---
  Future<int> insertProduto(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('produtos', row);
  }
  Future<int> updateProduto(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update('produtos', row, where: 'id = ?', whereArgs: [row['id']]);
  }
  Future<List<Map<String, dynamic>>> getProdutos() async {
    Database db = await database;
    return await db.query('produtos');
  }
  Future<int> deleteProduto(int id) async {
    Database db = await database;
    return await db.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }
  
  // Métodos Checklist
  Future<int> insertChecklistItem(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('checklist_operacional', row);
  }
  Future<List<Map<String, dynamic>>> getChecklist(int orcamentoId) async {
    Database db = await database;
    return await db.query('checklist_operacional', where: 'orcamento_id = ?', whereArgs: [orcamentoId]);
  }
  Future<int> toggleChecklistItem(int id, int status) async {
    Database db = await database;
    return await db.update('checklist_operacional', {'feito': status}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteChecklistItem(int id) async {
    Database db = await database;
    return await db.delete('checklist_operacional', where: 'id = ?', whereArgs: [id]);
  }

  // ======================================================
  // --- NOVAS FUNÇÕES: DASHBOARD E BACKUP ---
  // ======================================================

  // 1. DADOS PARA O DASHBOARD
  Future<Map<String, dynamic>> getDashboardData() async {
    Database db = await database;

    // A. Lucro Total (Apenas Confirmados)
    final resultLucro = await db.rawQuery(
      "SELECT SUM(total_lucro_servico) as total FROM orcamentos WHERE status = 'APROVADO'"
    );
    double lucroTotal = resultLucro.first['total'] != null ? resultLucro.first['total'] as double : 0.0;

    // B. Contagem de Shows (Aprovados vs Pendentes)
    final resultShows = await db.rawQuery(
      "SELECT status, COUNT(*) as qtd FROM orcamentos GROUP BY status"
    );
    
    // C. Top 5 Produtos Mais Usados (Em shows Aprovados)
    final resultTopProdutos = await db.rawQuery('''
      SELECT p.nome, SUM(i.quantidade) as qtd_total 
      FROM itens_orcamento i
      JOIN orcamentos o ON i.orcamento_id = o.id
      JOIN produtos p ON i.produto_id = p.id
      WHERE o.status = 'APROVADO'
      GROUP BY p.nome
      ORDER BY qtd_total DESC
      LIMIT 5
    ''');

    return {
      'lucroTotal': lucroTotal,
      'statusCounts': resultShows,
      'topProdutos': resultTopProdutos,
    };
  }

  // 2. EXPORTAR BACKUP (Gera arquivo .db e abre Share)
  Future<void> exportarBackup() async {
    String dbPath = join(await getDatabasesPath(), 'blaster_manager_v3.db');
    File dbFile = File(dbPath);

    if (await dbFile.exists()) {
      // Usa o SharePlus para enviar o arquivo (Drive, WhatsApp, Email)
      await Share.shareXFiles([XFile(dbPath)], text: 'Backup Blaster Manager');
    }
  }

  // 3. RESTAURAR BACKUP (Lê arquivo e substitui o atual)
  Future<bool> restaurarBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File backupFile = File(result.files.single.path!);
        String dbPath = join(await getDatabasesPath(), 'blaster_manager_v3.db');

        // Fecha o banco atual antes de substituir
        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }

        // Substitui o arquivo
        await backupFile.copy(dbPath);
        return true;
      }
      return false;
    } catch (e) {
      print("Erro ao restaurar: $e");
      return false;
    }
  }
}