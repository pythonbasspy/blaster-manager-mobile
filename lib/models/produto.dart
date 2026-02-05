class Produto {
  int? id;
  String nome;
  String categoria;
  int qtdEstoque;
  double valorReal;
  double valorCliente;
  
  // O lucro unitário é calculado, mas podemos salvar para histórico
  double get lucroUnitario => valorCliente - valorReal;

  Produto({
    this.id,
    required this.nome,
    required this.categoria,
    required this.qtdEstoque,
    required this.valorReal,
    required this.valorCliente,
  });

  // Converte para Map (para salvar no SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'categoria': categoria,
      'qtd_estoque': qtdEstoque,
      'valor_real': valorReal,
      'valor_cliente': valorCliente,
      'lucro_unitario': lucroUnitario,
    };
  }

  // Converte de Map (vindo do SQLite) para Objeto
  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      id: map['id'],
      nome: map['nome'],
      categoria: map['categoria'],
      qtdEstoque: map['qtd_estoque'],
      valorReal: map['valor_real'],
      valorCliente: map['valor_cliente'],
    );
  }
}