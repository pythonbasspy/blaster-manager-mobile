# 💥 Blaster Manager

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

> **Solução móvel completa para gestão operacional e financeira de shows pirotécnicos.**

O **Blaster Manager** foi desenvolvido para resolver uma dor latente no mercado de pirotecnia: a complexidade de orçar eventos considerando a alta volatilidade de insumos, logística de risco e margem de lucro real. O aplicativo permite que o Blaster (responsável técnico) gerencie estoques, crie orçamentos detalhados e gere documentos para o cliente em segundos, tudo offline.

---

## 📱 Funcionalidades Principais

### 1. Gestão de Orçamentos Inteligente
- Cálculo automático de lucro líquido vs. bruto.
- Inserção dinâmica de custos extras (logística, equipe, taxas).
- **Gerador de PDF:** Criação automática de orçamentos formais para envio ao cliente via WhatsApp/E-mail.

### 2. Controle de Estoque (Offline-First)
- Banco de dados local (SQLite) para funcionamento em áreas remotas sem internet.
- Baixa automática de estoque ao confirmar uma venda.
- Estorno automático de itens ao cancelar um orçamento.

### 3. Dashboard Gerencial
- Gráficos interativos (Pie Chart) de status de vendas.
- Indicador de Lucro Líquido Acumulado.
- Ranking "Top 5 Materiais Mais Utilizados".

### 4. Ferramentas Operacionais
- **Checklist de Carga:** Lista de conferência para equipamentos operacionais (não consumíveis).
- **Integração com Agenda:** Adiciona automaticamente a data do show ao calendário nativo do Android.
- **Backup & Restore:** Sistema de segurança para exportar o banco de dados para a nuvem (Google Drive/Files).

---

## 🛠️ Tecnologias Utilizadas

Este projeto foi construído com foco em performance, escalabilidade e experiência do usuário (UX).

- **Front-end:** Flutter (Dart).
- **Banco de Dados:** SQLite (sqflite) - Persistência de dados segura e offline.
- **Arquitetura:** MVC (Model-View-Controller) modificado para simplicidade e eficiência.
- **Bibliotecas Chave:**
  - `pdf` & `printing`: Geração de documentos.
  - `fl_chart`: Visualização de dados.
  - `add_2_calendar`: Integração nativa.
  - `share_plus` & `file_picker`: Manipulação de arquivos de backup.


---

## 🚀 Como rodar o projeto

### Pré-requisitos
- Flutter SDK instalado.
- Android Studio configurado (para emulador ou device físico).

### Instalação
1. Clone o repositório:
   ```bash
   git clone [https://github.com/SEU_USUARIO/blaster-manager.git](https://github.com/SEU_USUARIO/blaster-manager.git)

## 🚀 Desenvolvido por: *[pythonbasspy]
[https://www.linkedin.com/in/elias-rodrigues-de-oliveira-filho-43503123]
