-- =====================================================================
-- Barbearia The Family Hair - Script SQL (Entrega 2)
-- SGBD: MySQL 8.0.16 ou superior (CHECK so e aplicado a partir dessa versao)
-- Execucao: mysql -u root -p < docs/script.sql   (banco vazio ou recriado)
-- Convencoes: nomes em snake_case sem acento; datas em DATETIME; valores em
-- DECIMAL; dominios fechados em CHECK (valores sem acento).
-- Os nomes de tabelas e colunas sao os mesmos do dicionario de dados.
-- =====================================================================

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS barbearia_the_family_hair;
CREATE DATABASE barbearia_the_family_hair CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE barbearia_the_family_hair;

-- 2 e 3. CREATE TABLE com constraints (PK, FK, NOT NULL, UNIQUE, CHECK, DEFAULT)
-- Ordem de criacao respeita as dependencias entre tabelas.

-- cliente: Cadastro mínimo para localizar o cliente, confirmar reservas e prestar atendimento.
CREATE TABLE cliente (
  id_cliente INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  telefone VARCHAR(20) NOT NULL,
  email VARCHAR(100) NULL,
  data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_atualizacao DATETIME NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  aceita_marketing TINYINT(1) NOT NULL DEFAULT 0,
  data_consentimento_marketing DATETIME NULL,
  PRIMARY KEY (id_cliente),
  CONSTRAINT ck_cliente_email CHECK (email IS NULL OR email LIKE '%_@_%._%'),
  CONSTRAINT ck_cliente_ativo_bool CHECK (ativo IN (0, 1)),
  CONSTRAINT ck_cliente_aceita_marketing_bool CHECK (aceita_marketing IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- profissional: Representa os barbeiros que atendem na casa (atualmente dois, um por cadeira).
CREATE TABLE profissional (
  id_profissional INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  especialidade VARCHAR(100) NULL,
  telefone VARCHAR(20) NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id_profissional),
  CONSTRAINT ck_profissional_ativo_bool CHECK (ativo IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- servico: Catálogo de serviços principais (corte, barba, combo, sobrancelha, coloração, progressiva).
CREATE TABLE servico (
  id_servico INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  descricao VARCHAR(255) NULL,
  duracao INT NOT NULL,
  preco DECIMAL(10,2) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id_servico),
  CONSTRAINT ck_servico_duracao CHECK (duracao > 0),
  CONSTRAINT ck_servico_preco CHECK (preco >= 0),
  CONSTRAINT ck_servico_ativo_bool CHECK (ativo IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- servico_extra: Catálogo de adicionais opcionais (hidratação capilar, design etc.) contratados junto a um serviço principal.
CREATE TABLE servico_extra (
  id_extra INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  descricao VARCHAR(255) NULL,
  preco DECIMAL(10,2) NOT NULL,
  duracao INT NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id_extra),
  CONSTRAINT ck_servico_extra_preco CHECK (preco >= 0),
  CONSTRAINT ck_servico_extra_duracao CHECK (duracao > 0),
  CONSTRAINT ck_servico_extra_ativo_bool CHECK (ativo IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- usuario_sistema: Representa a identidade individual que opera o sistema e atribui autoria aos eventos auditáveis.
CREATE TABLE usuario_sistema (
  id_usuario INT NOT NULL AUTO_INCREMENT,
  nome_exibicao VARCHAR(100) NOT NULL,
  identificador_login VARCHAR(150) NOT NULL,
  perfil VARCHAR(30) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  data_criacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_desativacao DATETIME NULL,
  PRIMARY KEY (id_usuario),
  CONSTRAINT uq_usuario_sistema_identificador_login UNIQUE (identificador_login),
  CONSTRAINT ck_usuario_sistema_perfil_dom CHECK (perfil IN ('Administrador', 'Atendimento', 'Profissional')),
  CONSTRAINT ck_usuario_sistema_ativo_bool CHECK (ativo IN (0, 1)),
  CONSTRAINT ck_usuario_sistema_data_desativacao CHECK (ativo = 1 OR data_desativacao IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- log_auditoria: Trilha de auditoria da aplicação para atribuir ações a uma identidade e apoiar investigação e prestação de contas.
CREATE TABLE log_auditoria (
  id_log BIGINT NOT NULL AUTO_INCREMENT,
  id_usuario INT NOT NULL,
  data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  acao VARCHAR(40) NOT NULL,
  componente VARCHAR(20) NOT NULL,
  recurso VARCHAR(60) NOT NULL,
  resultado VARCHAR(20) NOT NULL,
  identificador_registro VARCHAR(100) NULL,
  origem VARCHAR(100) NULL,
  principal_sgbd VARCHAR(100) NULL,
  id_sessao_sgbd VARCHAR(100) NULL,
  id_correlacao VARCHAR(64) NULL,
  data_expurgo_prevista DATE NOT NULL,
  PRIMARY KEY (id_log),
  CONSTRAINT ck_log_auditoria_acao_dom CHECK (acao IN ('LOGIN', 'LOGIN_FALHA', 'CONSULTA', 'DML', 'DDL', 'ALTERACAO_PERMISSAO', 'EXPORTACAO', 'ESTORNO')),
  CONSTRAINT ck_log_auditoria_componente_dom CHECK (componente IN ('APLICACAO', 'SGBD')),
  CONSTRAINT ck_log_auditoria_resultado_dom CHECK (resultado IN ('SUCESSO', 'FALHA')),
  CONSTRAINT fk_log_auditoria_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- produto: Catálogo de produtos de revenda e insumos acompanhados pela barbearia.
CREATE TABLE produto (
  id_produto INT NOT NULL AUTO_INCREMENT,
  nome VARCHAR(120) NOT NULL,
  tipo_produto VARCHAR(15) NOT NULL,
  unidade_medida VARCHAR(15) NOT NULL,
  sku VARCHAR(50) NULL,
  descricao VARCHAR(255) NULL,
  preco_venda DECIMAL(10,2) NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  estoque_minimo DECIMAL(10,3) NULL,
  PRIMARY KEY (id_produto),
  CONSTRAINT ck_produto_tipo_produto_dom CHECK (tipo_produto IN ('Revenda', 'Insumo', 'Ambos')),
  CONSTRAINT uq_produto_sku UNIQUE (sku),
  CONSTRAINT ck_produto_preco_venda CHECK ((tipo_produto = 'Insumo' OR preco_venda IS NOT NULL) AND (preco_venda IS NULL OR preco_venda >= 0)),
  CONSTRAINT ck_produto_ativo_bool CHECK (ativo IN (0, 1)),
  CONSTRAINT ck_produto_estoque_minimo CHECK (estoque_minimo IS NULL OR estoque_minimo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- fornecedor: Cadastro de fornecedores para compras, recebimento de mercadorias e contas a pagar.
CREATE TABLE fornecedor (
  id_fornecedor INT NOT NULL AUTO_INCREMENT,
  nome_razao_social VARCHAR(150) NOT NULL,
  documento_fiscal VARCHAR(20) NULL,
  telefone VARCHAR(20) NULL,
  email VARCHAR(150) NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id_fornecedor),
  CONSTRAINT ck_fornecedor_ativo_bool CHECK (ativo IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- compra: Registra aquisição de produtos/insumos de um fornecedor e quem a lançou.
CREATE TABLE compra (
  id_compra INT NOT NULL AUTO_INCREMENT,
  id_fornecedor INT NOT NULL,
  id_usuario INT NOT NULL,
  data_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) NOT NULL,
  data_recebimento DATETIME NULL,
  valor_total DECIMAL(10,2) NOT NULL,
  observacao VARCHAR(255) NULL,
  PRIMARY KEY (id_compra),
  CONSTRAINT ck_compra_status_dom CHECK (status IN ('Rascunho', 'Pedida', 'Recebida', 'Cancelada')),
  CONSTRAINT ck_compra_data_recebimento CHECK (status <> 'Recebida' OR data_recebimento IS NOT NULL),
  CONSTRAINT ck_compra_valor_total CHECK (valor_total >= 0),
  CONSTRAINT fk_compra_id_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor (id_fornecedor),
  CONSTRAINT fk_compra_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- item_compra: Tabela associativa entre Compra e Produto (N:M).
CREATE TABLE item_compra (
  id_compra INT NOT NULL,
  id_produto INT NOT NULL,
  quantidade DECIMAL(10,3) NOT NULL,
  custo_unitario DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id_compra, id_produto),
  CONSTRAINT ck_item_compra_quantidade CHECK (quantidade > 0),
  CONSTRAINT ck_item_compra_custo_unitario CHECK (custo_unitario >= 0),
  CONSTRAINT fk_item_compra_id_compra FOREIGN KEY (id_compra) REFERENCES compra (id_compra),
  CONSTRAINT fk_item_compra_id_produto FOREIGN KEY (id_produto) REFERENCES produto (id_produto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- venda: Venda de balcão com operador obrigatório e cliente opcional.
CREATE TABLE venda (
  id_venda INT NOT NULL AUTO_INCREMENT,
  id_usuario INT NOT NULL,
  id_cliente INT NULL,
  data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) NOT NULL,
  valor_total DECIMAL(10,2) NOT NULL,
  forma_pagamento VARCHAR(30) NULL,
  PRIMARY KEY (id_venda),
  CONSTRAINT ck_venda_status_dom CHECK (status IN ('Aberta', 'Concluida', 'Cancelada')),
  CONSTRAINT ck_venda_valor_total CHECK (valor_total >= 0),
  CONSTRAINT ck_venda_forma_pagamento_dom CHECK (forma_pagamento IN ('Pix', 'Credito', 'Debito', 'Dinheiro')),
  CONSTRAINT ck_venda_forma_pagamento CHECK (status <> 'Concluida' OR forma_pagamento IS NOT NULL),
  CONSTRAINT fk_venda_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario),
  CONSTRAINT fk_venda_id_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- item_venda: Tabela associativa entre Venda e Produto (N:M).
CREATE TABLE item_venda (
  id_venda INT NOT NULL,
  id_produto INT NOT NULL,
  quantidade DECIMAL(10,3) NOT NULL,
  preco_unitario DECIMAL(10,2) NOT NULL,
  desconto_unitario DECIMAL(10,2) NULL,
  PRIMARY KEY (id_venda, id_produto),
  CONSTRAINT ck_item_venda_quantidade CHECK (quantidade > 0),
  CONSTRAINT ck_item_venda_preco_unitario CHECK (preco_unitario >= 0),
  CONSTRAINT ck_item_venda_desconto_unitario CHECK (desconto_unitario IS NULL OR (desconto_unitario >= 0 AND desconto_unitario <= preco_unitario)),
  CONSTRAINT fk_item_venda_id_venda FOREIGN KEY (id_venda) REFERENCES venda (id_venda),
  CONSTRAINT fk_item_venda_id_produto FOREIGN KEY (id_produto) REFERENCES produto (id_produto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- conta_pagar: Controla obrigações por vencimento, inclusive despesas recorrentes sem compra de estoque.
CREATE TABLE conta_pagar (
  id_conta INT NOT NULL AUTO_INCREMENT,
  id_fornecedor INT NULL,
  id_compra INT NULL,
  id_usuario INT NOT NULL,
  descricao VARCHAR(150) NOT NULL,
  categoria VARCHAR(40) NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  data_vencimento DATE NOT NULL,
  status VARCHAR(20) NOT NULL,
  data_baixa DATETIME NULL,
  PRIMARY KEY (id_conta),
  CONSTRAINT ck_conta_pagar_valor CHECK (valor > 0),
  CONSTRAINT ck_conta_pagar_status_dom CHECK (status IN ('Aberta', 'Paga', 'Atrasada', 'Cancelada')),
  CONSTRAINT ck_conta_pagar_data_baixa CHECK (status <> 'Paga' OR data_baixa IS NOT NULL),
  CONSTRAINT fk_conta_pagar_id_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor (id_fornecedor),
  CONSTRAINT fk_conta_pagar_id_compra FOREIGN KEY (id_compra) REFERENCES compra (id_compra),
  CONSTRAINT fk_conta_pagar_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- fechamento_caixa: Representa um turno/período de caixa.
CREATE TABLE fechamento_caixa (
  id_fechamento INT NOT NULL AUTO_INCREMENT,
  id_usuario INT NOT NULL,
  aberto_em DATETIME NOT NULL,
  fechado_em DATETIME NULL,
  saldo_abertura DECIMAL(10,2) NOT NULL,
  status VARCHAR(15) NOT NULL,
  PRIMARY KEY (id_fechamento),
  CONSTRAINT ck_fechamento_caixa_fechado_em CHECK (((status = 'Fechado') = (fechado_em IS NOT NULL)) AND (fechado_em IS NULL OR fechado_em >= aberto_em)),
  CONSTRAINT ck_fechamento_caixa_saldo_abertura CHECK (saldo_abertura >= 0),
  CONSTRAINT ck_fechamento_caixa_status_dom CHECK (status IN ('Aberto', 'Fechado')),
  CONSTRAINT fk_fechamento_caixa_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- fechamento_forma: Armazena o total conferido de cada forma de pagamento em um fechamento de caixa.
CREATE TABLE fechamento_forma (
  id_fechamento INT NOT NULL,
  forma_pagamento VARCHAR(20) NOT NULL,
  valor_esperado DECIMAL(10,2) NOT NULL,
  valor_conferido DECIMAL(10,2) NOT NULL,
  diferenca DECIMAL(10,2) GENERATED ALWAYS AS (valor_conferido - valor_esperado) STORED NOT NULL,
  PRIMARY KEY (id_fechamento, forma_pagamento),
  CONSTRAINT ck_fechamento_forma_forma_pagamento_dom CHECK (forma_pagamento IN ('Pix', 'Credito', 'Debito', 'Dinheiro')),
  CONSTRAINT fk_fechamento_forma_id_fechamento FOREIGN KEY (id_fechamento) REFERENCES fechamento_caixa (id_fechamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- registro_higienizacao: Registro operacional de limpeza/desinfecção de superfícies e processamento de instrumentos reutilizáveis, identificando responsável, etapa, método e resultado.
CREATE TABLE registro_higienizacao (
  id_registro BIGINT NOT NULL AUTO_INCREMENT,
  id_usuario INT NOT NULL,
  data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  item_area VARCHAR(100) NOT NULL,
  etapa VARCHAR(20) NOT NULL,
  metodo VARCHAR(120) NOT NULL,
  produto_lote VARCHAR(100) NULL,
  referencia_ciclo VARCHAR(100) NULL,
  resultado VARCHAR(20) NOT NULL,
  observacao VARCHAR(255) NULL,
  PRIMARY KEY (id_registro),
  CONSTRAINT ck_registro_higienizacao_resultado_dom CHECK (resultado IN ('Aprovado', 'Reprovado')),
  CONSTRAINT fk_registro_higienizacao_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- regra_calendario: Armazena o expediente semanal e exceções pontuais, inclusive feriados abertos/fechados.
CREATE TABLE regra_calendario (
  id_regra_calendario INT NOT NULL AUTO_INCREMENT,
  tipo_regra VARCHAR(15) NOT NULL,
  dia_semana TINYINT NULL,
  data_especifica DATE NULL,
  situacao VARCHAR(10) NOT NULL,
  hora_abertura TIME NULL,
  hora_fechamento TIME NULL,
  vigencia_inicio DATE NOT NULL,
  vigencia_fim DATE NULL,
  motivo VARCHAR(120) NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id_regra_calendario),
  CONSTRAINT ck_regra_calendario_tipo_regra_dom CHECK (tipo_regra IN ('SEMANAL', 'EXCECAO')),
  CONSTRAINT ck_regra_calendario_dia_semana CHECK ((tipo_regra = 'SEMANAL' AND dia_semana BETWEEN 1 AND 7 AND data_especifica IS NULL) OR (tipo_regra = 'EXCECAO' AND dia_semana IS NULL AND data_especifica IS NOT NULL)),
  CONSTRAINT ck_regra_calendario_situacao_dom CHECK (situacao IN ('ABERTO', 'FECHADO')),
  CONSTRAINT ck_regra_calendario_hora_fechamento CHECK ((situacao = 'ABERTO' AND hora_abertura IS NOT NULL AND hora_fechamento IS NOT NULL AND hora_fechamento > hora_abertura) OR (situacao = 'FECHADO' AND hora_abertura IS NULL AND hora_fechamento IS NULL)),
  CONSTRAINT ck_regra_calendario_vigencia_fim CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT ck_regra_calendario_ativo_bool CHECK (ativo IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- agendamento: Entidade central do modelo: conecta cliente, profissional, serviços, extras, pagamento e avaliação.
CREATE TABLE agendamento (
  id_agendamento INT NOT NULL AUTO_INCREMENT,
  id_cliente INT NOT NULL,
  id_profissional INT NOT NULL,
  id_regra_calendario INT NOT NULL,
  data DATE NOT NULL,
  hora_inicio TIME NOT NULL,
  hora_fim TIME NOT NULL,
  status VARCHAR(30) NOT NULL,
  politica_reserva_versao VARCHAR(30) NOT NULL,
  politica_aceita_em DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expira_em DATETIME NULL,
  confirmado_em DATETIME NULL,
  checkin_em DATETIME NULL,
  cancelado_em DATETIME NULL,
  motivo_cancelamento VARCHAR(255) NULL,
  observacao VARCHAR(255) NULL,
  PRIMARY KEY (id_agendamento),
  CONSTRAINT ck_agendamento_hora_inicio CHECK (hora_inicio BETWEEN '08:00:00' AND '19:00:00'),
  CONSTRAINT ck_agendamento_hora_fim CHECK (hora_fim > hora_inicio AND hora_fim <= '19:00:00'),
  CONSTRAINT ck_agendamento_status_dom CHECK (status IN ('Aguardando_pagamento', 'Confirmado', 'Concluido', 'Cancelado', 'Faltou')),
  CONSTRAINT ck_agendamento_expira_em CHECK (status <> 'Aguardando_pagamento' OR expira_em IS NOT NULL),
  CONSTRAINT ck_agendamento_confirmado_em CHECK (status NOT IN ('Confirmado','Concluido','Faltou') OR confirmado_em IS NOT NULL),
  CONSTRAINT ck_agendamento_cancelado_em CHECK (status <> 'Cancelado' OR cancelado_em IS NOT NULL),
  CONSTRAINT fk_agendamento_id_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
  CONSTRAINT fk_agendamento_id_profissional FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional),
  CONSTRAINT fk_agendamento_id_regra_calendario FOREIGN KEY (id_regra_calendario) REFERENCES regra_calendario (id_regra_calendario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- agendamento_servico: Tabela associativa entre Agendamento e Servico (N:M).
CREATE TABLE agendamento_servico (
  id_agendamento INT NOT NULL,
  id_servico INT NOT NULL,
  preco_contratado DECIMAL(10,2) NOT NULL,
  duracao_contratada SMALLINT NOT NULL,
  PRIMARY KEY (id_agendamento, id_servico),
  CONSTRAINT ck_agendamento_servico_preco_contratado CHECK (preco_contratado >= 0),
  CONSTRAINT ck_agendamento_servico_duracao_contratada CHECK (duracao_contratada > 0),
  CONSTRAINT fk_agendamento_servico_id_agendamento FOREIGN KEY (id_agendamento) REFERENCES agendamento (id_agendamento),
  CONSTRAINT fk_agendamento_servico_id_servico FOREIGN KEY (id_servico) REFERENCES servico (id_servico)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- agendamento_extra: Tabela associativa entre Agendamento e Servico_extra (N:M).
CREATE TABLE agendamento_extra (
  id_agendamento INT NOT NULL,
  id_extra INT NOT NULL,
  preco_contratado DECIMAL(10,2) NOT NULL,
  duracao_contratada SMALLINT NOT NULL,
  PRIMARY KEY (id_agendamento, id_extra),
  CONSTRAINT ck_agendamento_extra_preco_contratado CHECK (preco_contratado >= 0),
  CONSTRAINT ck_agendamento_extra_duracao_contratada CHECK (duracao_contratada > 0),
  CONSTRAINT fk_agendamento_extra_id_agendamento FOREIGN KEY (id_agendamento) REFERENCES agendamento (id_agendamento),
  CONSTRAINT fk_agendamento_extra_id_extra FOREIGN KEY (id_extra) REFERENCES servico_extra (id_extra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- pagamento: Registra tentativas e capturas para o agendamento.
CREATE TABLE pagamento (
  id_pagamento INT NOT NULL AUTO_INCREMENT,
  id_agendamento INT NOT NULL,
  id_pagamento_origem INT NULL,
  tipo_operacao VARCHAR(20) NOT NULL,
  forma_pagamento VARCHAR(30) NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  status VARCHAR(30) NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmado_em DATETIME NULL,
  referencia_provedor VARCHAR(100) NULL,
  chave_idempotencia VARCHAR(100) NULL,
  PRIMARY KEY (id_pagamento),
  CONSTRAINT ck_pagamento_id_pagamento_origem CHECK ((tipo_operacao = 'Estorno') = (id_pagamento_origem IS NOT NULL)),
  CONSTRAINT ck_pagamento_tipo_operacao_dom CHECK (tipo_operacao IN ('Cobranca', 'Estorno')),
  CONSTRAINT ck_pagamento_forma_pagamento_dom CHECK (forma_pagamento IN ('Pix', 'Credito', 'Debito', 'Dinheiro')),
  CONSTRAINT ck_pagamento_valor CHECK (valor > 0),
  CONSTRAINT ck_pagamento_status_dom CHECK (status IN ('Pendente', 'Pago', 'Falhou')),
  CONSTRAINT ck_pagamento_confirmado_em CHECK (status <> 'Pago' OR confirmado_em IS NOT NULL),
  CONSTRAINT uq_pagamento_chave_idempotencia UNIQUE (chave_idempotencia),
  CONSTRAINT fk_pagamento_id_agendamento FOREIGN KEY (id_agendamento) REFERENCES agendamento (id_agendamento),
  CONSTRAINT fk_pagamento_id_pagamento_origem FOREIGN KEY (id_pagamento_origem) REFERENCES pagamento (id_pagamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- avaliacao: Permite ao cliente avaliar o serviço após a execução, apoiando a melhoria contínua e o controle de qualidade.
CREATE TABLE avaliacao (
  id_avaliacao INT NOT NULL AUTO_INCREMENT,
  id_agendamento INT NOT NULL,
  nota INT NOT NULL,
  comentario VARCHAR(500) NULL,
  data_avaliacao DATETIME NOT NULL,
  PRIMARY KEY (id_avaliacao),
  CONSTRAINT uq_avaliacao_id_agendamento UNIQUE (id_agendamento),
  CONSTRAINT ck_avaliacao_nota CHECK (nota BETWEEN 1 AND 5),
  CONSTRAINT fk_avaliacao_id_agendamento FOREIGN KEY (id_agendamento) REFERENCES agendamento (id_agendamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- movimento_caixa: Livro de movimentos financeiros efetivamente recebidos ou pagos, distinguindo agendamentos, vendas e contas.
CREATE TABLE movimento_caixa (
  id_movimento BIGINT NOT NULL AUTO_INCREMENT,
  id_usuario INT NOT NULL,
  id_pagamento INT NULL,
  id_venda INT NULL,
  id_conta INT NULL,
  id_fechamento INT NULL,
  tipo VARCHAR(20) NOT NULL,
  forma_pagamento VARCHAR(20) NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo VARCHAR(255) NULL,
  PRIMARY KEY (id_movimento),
  CONSTRAINT ck_movimento_caixa_id_pagamento CHECK (((id_pagamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_conta IS NOT NULL)) = 1 OR (tipo = 'Ajuste' AND ((id_pagamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_conta IS NOT NULL)) <= 1)),
  CONSTRAINT ck_movimento_caixa_tipo_dom CHECK (tipo IN ('Entrada', 'Saida', 'Estorno', 'Ajuste')),
  CONSTRAINT ck_movimento_caixa_forma_pagamento_dom CHECK (forma_pagamento IN ('Pix', 'Credito', 'Debito', 'Dinheiro')),
  CONSTRAINT ck_movimento_caixa_valor CHECK (valor > 0),
  CONSTRAINT ck_movimento_caixa_motivo CHECK (tipo NOT IN ('Ajuste','Estorno') OR motivo IS NOT NULL),
  CONSTRAINT fk_movimento_caixa_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario),
  CONSTRAINT fk_movimento_caixa_id_pagamento FOREIGN KEY (id_pagamento) REFERENCES pagamento (id_pagamento),
  CONSTRAINT fk_movimento_caixa_id_venda FOREIGN KEY (id_venda) REFERENCES venda (id_venda),
  CONSTRAINT fk_movimento_caixa_id_conta FOREIGN KEY (id_conta) REFERENCES conta_pagar (id_conta),
  CONSTRAINT fk_movimento_caixa_id_fechamento FOREIGN KEY (id_fechamento) REFERENCES fechamento_caixa (id_fechamento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- movimento_estoque: Razão imutável de estoque por produto.
CREATE TABLE movimento_estoque (
  id_mov_estoque BIGINT NOT NULL AUTO_INCREMENT,
  id_produto INT NOT NULL,
  id_usuario INT NOT NULL,
  id_compra INT NULL,
  id_venda INT NULL,
  id_registro_higienizacao BIGINT NULL,
  tipo VARCHAR(15) NOT NULL,
  quantidade DECIMAL(10,3) NOT NULL,
  custo_unitario DECIMAL(10,4) NULL,
  data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo VARCHAR(255) NULL,
  PRIMARY KEY (id_mov_estoque),
  CONSTRAINT ck_movimento_estoque_tipo_dom CHECK (tipo IN ('Entrada', 'Saida', 'Ajuste')),
  CONSTRAINT ck_movimento_estoque_tipo CHECK ((tipo = 'Entrada' AND id_venda IS NULL AND id_registro_higienizacao IS NULL) OR (tipo = 'Saida' AND id_compra IS NULL AND ((id_venda IS NOT NULL) + (id_registro_higienizacao IS NOT NULL)) <= 1) OR (tipo = 'Ajuste' AND id_compra IS NULL AND id_venda IS NULL AND id_registro_higienizacao IS NULL AND motivo IS NOT NULL)),
  CONSTRAINT ck_movimento_estoque_quantidade CHECK (quantidade > 0),
  CONSTRAINT ck_movimento_estoque_custo_unitario CHECK (custo_unitario IS NULL OR custo_unitario >= 0),
  CONSTRAINT fk_movimento_estoque_id_produto FOREIGN KEY (id_produto) REFERENCES produto (id_produto),
  CONSTRAINT fk_movimento_estoque_id_usuario FOREIGN KEY (id_usuario) REFERENCES usuario_sistema (id_usuario),
  CONSTRAINT fk_movimento_estoque_id_registro_higienizacao FOREIGN KEY (id_registro_higienizacao) REFERENCES registro_higienizacao (id_registro),
  CONSTRAINT fk_movimento_estoque_item_compra FOREIGN KEY (id_compra, id_produto) REFERENCES item_compra (id_compra, id_produto),
  CONSTRAINT fk_movimento_estoque_item_venda FOREIGN KEY (id_venda, id_produto) REFERENCES item_venda (id_venda, id_produto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- documento_fiscal: Referência ao documento fiscal emitido para prestação de serviço/agendamento, venda de produto ou recebido do fornecedor numa compra.
CREATE TABLE documento_fiscal (
  id_documento BIGINT NOT NULL AUTO_INCREMENT,
  id_agendamento INT NULL,
  id_venda INT NULL,
  id_compra INT NULL,
  tipo VARCHAR(30) NOT NULL,
  numero VARCHAR(30) NOT NULL,
  serie VARCHAR(20) NULL,
  chave_acesso VARCHAR(60) NULL,
  emitido_em DATETIME NOT NULL,
  status VARCHAR(20) NOT NULL,
  localizador_arquivo VARCHAR(255) NULL,
  PRIMARY KEY (id_documento),
  CONSTRAINT ck_documento_fiscal_id_compra CHECK (((id_agendamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_compra IS NOT NULL)) = 1),
  CONSTRAINT uq_documento_fiscal_numero UNIQUE (tipo, serie, numero),
  CONSTRAINT fk_documento_fiscal_id_agendamento FOREIGN KEY (id_agendamento) REFERENCES agendamento (id_agendamento),
  CONSTRAINT fk_documento_fiscal_id_venda FOREIGN KEY (id_venda) REFERENCES venda (id_venda),
  CONSTRAINT fk_documento_fiscal_id_compra FOREIGN KEY (id_compra) REFERENCES compra (id_compra)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indices de apoio as consultas (as FKs ja criam indice proprio no InnoDB)
CREATE INDEX ix_cliente_telefone ON cliente (telefone);
CREATE INDEX ix_profissional_ativo ON profissional (ativo);
CREATE INDEX ix_agendamento_prof_data ON agendamento (id_profissional, data, hora_inicio);
CREATE INDEX ix_agendamento_status ON agendamento (status);
CREATE INDEX ix_pagamento_agend_status ON pagamento (id_agendamento, status);
CREATE INDEX ix_pagamento_status_criado ON pagamento (status, criado_em);

-- 4. INSERT INTO (massa de dados): ver docs/massa_de_dados.sql
-- 5. SELECT com JOIN, 6. UPDATE, 7. DELETE e 8. consultas gerenciais (G01...): a incluir

-- 9. CONSULTAS DE AUDITORIA

-- A01 - Existem agendamentos de um mesmo profissional com horarios sobrepostos?
-- Verifica: RN09 (um profissional nao pode ter dois agendamentos sobrepostos)
SELECT a1.id_agendamento AS agendamento_1, a2.id_agendamento AS agendamento_2, a1.id_profissional, a1.data,
       a1.hora_inicio AS inicio_1, a1.hora_fim AS fim_1, a2.hora_inicio AS inicio_2, a2.hora_fim AS fim_2
FROM agendamento a1
JOIN agendamento a2 ON a2.id_profissional = a1.id_profissional AND a2.data = a1.data
 AND a1.id_agendamento < a2.id_agendamento
 AND a1.hora_inicio < a2.hora_fim AND a2.hora_inicio < a1.hora_fim
WHERE a1.status <> 'Cancelado' AND a2.status <> 'Cancelado';

-- A02 - Existe agendamento sem nenhum servico contratado?
-- Verifica: RN05 (a janela reservada e a soma das duracoes contratadas; sem servico nao ha janela)
SELECT a.id_agendamento, a.data, a.hora_inicio, a.status
FROM agendamento a
LEFT JOIN agendamento_servico s ON s.id_agendamento = a.id_agendamento
WHERE s.id_agendamento IS NULL;

-- A03 - Algum agendamento tem hora_fim diferente da soma das duracoes contratadas?
-- Verifica: RN05 (hora_fim calculada pelas duracoes de servicos e extras)
SELECT a.id_agendamento, a.hora_inicio, a.hora_fim,
       SEC_TO_TIME(TIME_TO_SEC(a.hora_inicio) + 60 * (COALESCE(s.minutos, 0) + COALESCE(e.minutos, 0))) AS fim_esperado
FROM agendamento a
LEFT JOIN (SELECT id_agendamento, SUM(duracao_contratada) AS minutos FROM agendamento_servico GROUP BY id_agendamento) s
       ON s.id_agendamento = a.id_agendamento
LEFT JOIN (SELECT id_agendamento, SUM(duracao_contratada) AS minutos FROM agendamento_extra GROUP BY id_agendamento) e
       ON e.id_agendamento = a.id_agendamento
WHERE a.hora_fim <> SEC_TO_TIME(TIME_TO_SEC(a.hora_inicio) + 60 * (COALESCE(s.minutos, 0) + COALESCE(e.minutos, 0)));

-- A04 - Existe reserva confirmada sem pagamento aprovado cobrindo o total?
-- Verifica: RN11 (apenas pagamentos confirmados geram reserva Confirmada) e RN02 (sem fiado)
SELECT a.id_agendamento, a.status, COALESCE(t.total, 0) AS total_devido, COALESCE(p.pago, 0) AS total_pago
FROM agendamento a
LEFT JOIN (SELECT id_agendamento, SUM(preco) AS total
           FROM (SELECT id_agendamento, preco_contratado AS preco FROM agendamento_servico
                 UNION ALL
                 SELECT id_agendamento, preco_contratado FROM agendamento_extra) x
           GROUP BY id_agendamento) t ON t.id_agendamento = a.id_agendamento
LEFT JOIN (SELECT id_agendamento,
                  SUM(CASE WHEN tipo_operacao = 'Cobranca' THEN valor ELSE -valor END) AS pago
           FROM pagamento WHERE status = 'Pago' GROUP BY id_agendamento) p ON p.id_agendamento = a.id_agendamento
WHERE a.status IN ('Confirmado', 'Concluido', 'Faltou') AND COALESCE(p.pago, 0) < COALESCE(t.total, 0);

-- A05 - Existe reserva aguardando pagamento com prazo vencido que ainda ocupa o horario?
-- Verifica: RN18 (reserva Aguardando_pagamento expira e libera o horario)
SELECT id_agendamento, id_profissional, data, hora_inicio, expira_em
FROM agendamento
WHERE status = 'Aguardando_pagamento' AND expira_em < NOW();

-- A06 - Existe movimento de caixa registrado depois do fechamento do caixa a que pertence?
-- Verifica: RN14 (movimento de caixa fechado nao pode ser sobrescrito)
SELECT m.id_movimento, m.id_fechamento, m.data_hora, f.fechado_em
FROM movimento_caixa m
JOIN fechamento_caixa f ON f.id_fechamento = m.id_fechamento
WHERE f.status = 'Fechado' AND m.data_hora > f.fechado_em;

-- A07 - Existe avaliacao de agendamento nao concluido ou anterior ao fim do atendimento?
-- Verifica: regra de avaliacao (so apos status Concluido, com data posterior ao fim do atendimento)
SELECT v.id_avaliacao, a.id_agendamento, a.status, v.data_avaliacao
FROM avaliacao v
JOIN agendamento a ON a.id_agendamento = v.id_agendamento
WHERE a.status <> 'Concluido' OR v.data_avaliacao < TIMESTAMP(a.data, a.hora_fim);

-- A08 - Existem dois servicos ativos com o mesmo nome?
-- Verifica: unicidade do nome entre servicos ativos (catalogo, RN08)
SELECT nome, COUNT(*) AS qtd FROM servico WHERE ativo = 1 GROUP BY nome HAVING COUNT(*) > 1;
