import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();
  
  final _nomeController = TextEditingController();
  final _estoqueController = TextEditingController();
  final _custoController = TextEditingController();
  final _vendaController = TextEditingController();
  
  // Variável para saber se estamos editando um item existente
  Produto? _produtoEmEdicao;
  
  List<Produto> _listaProdutos = [];

  @override
  void initState() {
    super.initState();
    _atualizarLista();
  }

  void _atualizarLista() async {
    final data = await dbHelper.getProdutos();
    setState(() {
      _listaProdutos = data.map((item) => Produto.fromMap(item)).toList();
    });
  }

  void _salvarProduto() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      double custo = double.parse(_custoController.text.replaceAll(',', '.'));
      double venda = double.parse(_vendaController.text.replaceAll(',', '.'));
      int estoque = int.parse(_estoqueController.text);

      Produto produto = Produto(
        id: _produtoEmEdicao?.id, // Se for edição, mantém o ID
        nome: _nomeController.text,
        categoria: 'Geral',
        qtdEstoque: estoque,
        valorReal: custo,
        valorCliente: venda,
      );

      if (_produtoEmEdicao == null) {
        // Novo cadastro
        await dbHelper.insertProduto(produto.toMap());
      } else {
        // Atualização (Edição)
        await dbHelper.updateProduto(produto.toMap());
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_produtoEmEdicao == null ? 'Produto criado!' : 'Produto atualizado!'),
            backgroundColor: Colors.green
          ),
        );
      }

      _limparFormulario();
      Navigator.of(context).pop(); 
      _atualizarLista();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: Verifique os valores numéricos. ($e)'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmarExclusao(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Item?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await dbHelper.deleteProduto(id);
              if (mounted) Navigator.of(ctx).pop();
              _atualizarLista();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _limparFormulario() {
    _nomeController.clear();
    _estoqueController.clear();
    _custoController.clear();
    _vendaController.clear();
    _produtoEmEdicao = null;
  }

  void _abrirFormulario({Produto? produtoParaEditar}) {
    // Se recebeu um produto, preenche os campos
    if (produtoParaEditar != null) {
      _produtoEmEdicao = produtoParaEditar;
      _nomeController.text = produtoParaEditar.nome;
      _estoqueController.text = produtoParaEditar.qtdEstoque.toString();
      _custoController.text = produtoParaEditar.valorReal.toStringAsFixed(2).replaceAll('.', ',');
      _vendaController.text = produtoParaEditar.valorCliente.toStringAsFixed(2).replaceAll('.', ',');
    } else {
      _limparFormulario();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _produtoEmEdicao == null ? 'Novo Item' : 'Editar Item',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Item'),
                validator: (val) => val!.isEmpty ? 'Digite um nome' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _estoqueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Qtd Estoque'),
                      validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _custoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Custo (R\$)'),
                      validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _vendaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor Revenda (R\$)'),
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarProduto,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                child: Text(_produtoEmEdicao == null ? 'SALVAR' : 'ATUALIZAR'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      appBar: AppBar(title: const Text('Inventário / Estoque')),
      body: _listaProdutos.isEmpty 
        ? const Center(child: Text('Nenhum item cadastrado.'))
        : ListView.builder(
            itemCount: _listaProdutos.length,
            itemBuilder: (context, index) {
              final item = _listaProdutos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  onTap: () => _abrirFormulario(produtoParaEditar: item), // Toque para editar
                  title: Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Estoque: ${item.qtdEstoque} un | Custo: ${currency.format(item.valorReal)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currency.format(item.valorCliente), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          Text('Lucro: ${currency.format(item.lucroUnitario)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmarExclusao(item.id!),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}