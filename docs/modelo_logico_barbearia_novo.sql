-- Script convertido para MySQL 8.0.16+ (CHECK só é aplicado a partir dessa versão;
-- índices funcionais exigem 8.0.13+). Engine InnoDB, charset utf8mb4.
-- Recomenda-se rodar o servidor com time_zone = '+00:00' (os campos DATETIME guardam UTC).

SET NAMES utf8mb4;

CREATE TABLE `follows` (
  `following_user_id` INTEGER NOT NULL,
  `followed_user_id` INTEGER NOT NULL,
  `created_at` DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `users` (
  `id` INTEGER PRIMARY KEY,
  `username` VARCHAR(255),
  `role` VARCHAR(255),
  `created_at` DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `posts` (
  `id` INTEGER PRIMARY KEY,
  `title` VARCHAR(255),
  `body` TEXT COMMENT 'Content of the post',
  `user_id` INTEGER NOT NULL,
  `status` VARCHAR(255),
  `created_at` DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `usuario_sistema` (
  `id_usuario` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome_exibicao` VARCHAR(100) NOT NULL,
  `identificador_login` VARCHAR(150) NOT NULL,
  `perfil` VARCHAR(30) NOT NULL,
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  `data_criacao` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `data_desativacao` DATETIME NULL,
  CONSTRAINT `ck_usuario_perfil` CHECK (perfil IN ('Administrador','Atendimento','Profissional')),
  CONSTRAINT `ck_usuario_desativacao` CHECK ((ativo = TRUE  AND data_desativacao IS NULL) OR
        (ativo = FALSE AND data_desativacao IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `log_auditoria` (
  `id_log` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `id_usuario` INTEGER NOT NULL,
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `acao` VARCHAR(40) NOT NULL,
  `componente` VARCHAR(20) NOT NULL,
  `recurso` VARCHAR(60) NOT NULL,
  `resultado` VARCHAR(20) NOT NULL,
  `identificador_registro` VARCHAR(100),
  `origem` VARCHAR(100),
  `principal_sgbd` VARCHAR(100),
  `id_sessao_sgbd` VARCHAR(100),
  `id_correlacao` VARCHAR(64),
  `data_expurgo_prevista` DATE NOT NULL,
  CONSTRAINT `ck_log_acao` CHECK (acao IN ('LOGIN','LOGIN_FALHA','CONSULTA','DML','DDL',
                                           'ALTERACAO_PERMISSAO','EXPORTACAO','ESTORNO')),
  CONSTRAINT `ck_log_componente` CHECK (componente IN ('APLICACAO','SGBD')),
  CONSTRAINT `ck_log_resultado` CHECK (resultado IN ('SUCESSO','FALHA'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `cliente` (
  `id_cliente` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome` VARCHAR(100) NOT NULL,
  `telefone` VARCHAR(20) NOT NULL,
  `email` VARCHAR(100),
  `data_cadastro` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `data_atualizacao` DATETIME NULL,
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  `aceita_marketing` BOOLEAN NOT NULL DEFAULT FALSE,
  `data_consentimento_marketing` DATETIME NULL,
  CONSTRAINT `ck_cliente_email` CHECK (email IS NULL OR email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
  CONSTRAINT `ck_cliente_consent` CHECK (aceita_marketing = FALSE OR data_consentimento_marketing IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `profissional` (
  `id_profissional` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome` VARCHAR(100) NOT NULL,
  `especialidade` VARCHAR(100),
  `telefone` VARCHAR(20),
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `servico` (
  `id_servico` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome` VARCHAR(100) NOT NULL,
  `descricao` VARCHAR(255),
  `duracao` INTEGER NOT NULL,
  `preco` DECIMAL(10,2) NOT NULL,
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT `ck_servico_duracao` CHECK (duracao > 0),
  CONSTRAINT `ck_servico_preco` CHECK (preco >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `servico_extra` (
  `id_extra` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome` VARCHAR(100) NOT NULL,
  `descricao` VARCHAR(255),
  `preco` DECIMAL(10,2) NOT NULL,
  `duracao` INTEGER NOT NULL,
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT `ck_extra_duracao` CHECK (duracao >= 0),
  CONSTRAINT `ck_extra_preco` CHECK (preco >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `regra_calendario` (
  `id_regra_calendario` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `tipo_regra` VARCHAR(15) NOT NULL,
  `dia_semana` SMALLINT,
  `data_especifica` DATE,
  `situacao` VARCHAR(10) NOT NULL,
  `hora_abertura` TIME,
  `hora_fechamento` TIME,
  `vigencia_inicio` DATE NOT NULL,
  `vigencia_fim` DATE,
  `motivo` VARCHAR(120),
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT `ck_regra_tipo` CHECK (tipo_regra IN ('SEMANAL','EXCECAO')),
  CONSTRAINT `ck_regra_situacao` CHECK (situacao IN ('ABERTO','FECHADO')),
  CONSTRAINT `ck_regra_dia` CHECK (dia_semana IS NULL OR dia_semana BETWEEN 1 AND 7),
  CONSTRAINT `ck_regra_vigencia` CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
  CONSTRAINT `ck_regra_tipo_campos` CHECK ((tipo_regra = 'SEMANAL' AND dia_semana IS NOT NULL AND data_especifica IS NULL) OR
        (tipo_regra = 'EXCECAO' AND data_especifica IS NOT NULL AND dia_semana IS NULL)),
  CONSTRAINT `ck_regra_horarios` CHECK ((situacao = 'ABERTO'  AND hora_abertura IS NOT NULL AND hora_fechamento IS NOT NULL
                              AND hora_fechamento > hora_abertura) OR
        (situacao = 'FECHADO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `agendamento` (
  `id_agendamento` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_cliente` INTEGER NOT NULL,
  `id_profissional` INTEGER NOT NULL,
  `id_regra_calendario` INTEGER NOT NULL,
  `data` DATE NOT NULL,
  `hora_inicio` TIME NOT NULL,
  `hora_fim` TIME NOT NULL,
  `status` VARCHAR(30) NOT NULL DEFAULT 'Aguardando_pagamento',
  `politica_reserva_versao` VARCHAR(30) NOT NULL,
  `politica_aceita_em` DATETIME NOT NULL,
  `criado_em` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expira_em` DATETIME NULL,
  `confirmado_em` DATETIME NULL,
  `checkin_em` DATETIME NULL,
  `cancelado_em` DATETIME NULL,
  `motivo_cancelamento` VARCHAR(255),
  `observacao` VARCHAR(255),
  CONSTRAINT `ck_agend_status` CHECK (status IN ('Aguardando_pagamento','Confirmado','Concluido','Cancelado','Faltou')),
  CONSTRAINT `ck_agend_horas` CHECK (hora_fim > hora_inicio),
  CONSTRAINT `ck_agend_expira` CHECK (status <> 'Aguardando_pagamento' OR expira_em IS NOT NULL),
  CONSTRAINT `ck_agend_confirmado` CHECK (status NOT IN ('Confirmado','Concluido','Faltou') OR confirmado_em IS NOT NULL),
  CONSTRAINT `ck_agend_cancelado` CHECK (status <> 'Cancelado' OR cancelado_em IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `agendamento_servico` (
  `id_agendamento` INTEGER NOT NULL,
  `id_servico` INTEGER NOT NULL,
  `preco_contratado` DECIMAL(10,2) NOT NULL,
  `duracao_contratada` SMALLINT NOT NULL,
  CONSTRAINT `ck_ags_preco` CHECK (preco_contratado >= 0),
  CONSTRAINT `ck_ags_duracao` CHECK (duracao_contratada > 0),
  PRIMARY KEY (`id_agendamento`, `id_servico`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `agendamento_extra` (
  `id_agendamento` INTEGER NOT NULL,
  `id_extra` INTEGER NOT NULL,
  `preco_contratado` DECIMAL(10,2) NOT NULL,
  `duracao_contratada` SMALLINT NOT NULL,
  CONSTRAINT `ck_age_preco` CHECK (preco_contratado >= 0),
  CONSTRAINT `ck_age_duracao` CHECK (duracao_contratada >= 0),
  PRIMARY KEY (`id_agendamento`, `id_extra`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `pagamento` (
  `id_pagamento` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_agendamento` INTEGER NOT NULL,
  `id_pagamento_origem` INTEGER,
  `tipo_operacao` VARCHAR(20) NOT NULL,
  `forma_pagamento` VARCHAR(30) NOT NULL,
  `valor` DECIMAL(10,2) NOT NULL,
  `status` VARCHAR(30) NOT NULL,
  `criado_em` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `confirmado_em` DATETIME NULL,
  `referencia_provedor` VARCHAR(100),
  `chave_idempotencia` VARCHAR(100),
  CONSTRAINT `ck_pag_tipo` CHECK (tipo_operacao IN ('Cobranca','Estorno')),
  CONSTRAINT `ck_pag_forma` CHECK (forma_pagamento IN ('Pix','Credito','Debito','Dinheiro')),
  CONSTRAINT `ck_pag_status` CHECK (status IN ('Pendente','Pago','Falhou')),
  CONSTRAINT `ck_pag_valor` CHECK (valor > 0),
  CONSTRAINT `ck_pag_confirmado` CHECK (status <> 'Pago' OR confirmado_em IS NOT NULL),
  CONSTRAINT `ck_pag_estorno_origem` CHECK ((tipo_operacao = 'Estorno'  AND id_pagamento_origem IS NOT NULL) OR
        (tipo_operacao = 'Cobranca' AND id_pagamento_origem IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `avaliacao` (
  `id_avaliacao` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_agendamento` INTEGER NOT NULL,
  `nota` INTEGER NOT NULL,
  `comentario` VARCHAR(500),
  `data_avaliacao` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `ck_aval_nota` CHECK (nota BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `produto` (
  `id_produto` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome` VARCHAR(120) NOT NULL,
  `tipo_produto` VARCHAR(15) NOT NULL,
  `unidade_medida` VARCHAR(15) NOT NULL,
  `sku` VARCHAR(50),
  `descricao` VARCHAR(255),
  `preco_venda` DECIMAL(10,2),
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  `estoque_minimo` DECIMAL(10,3),
  CONSTRAINT `ck_produto_tipo` CHECK (tipo_produto IN ('Revenda','Insumo','Ambos')),
  CONSTRAINT `ck_produto_preco` CHECK (preco_venda IS NULL OR preco_venda >= 0),
  CONSTRAINT `ck_produto_minimo` CHECK (estoque_minimo IS NULL OR estoque_minimo >= 0),
  CONSTRAINT `ck_produto_preco_revenda` CHECK (tipo_produto = 'Insumo' OR preco_venda IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `fornecedor` (
  `id_fornecedor` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `nome_razao_social` VARCHAR(150) NOT NULL,
  `documento_fiscal` VARCHAR(20),
  `telefone` VARCHAR(20),
  `email` VARCHAR(150),
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT `ck_fornecedor_email` CHECK (email IS NULL OR email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `compra` (
  `id_compra` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_fornecedor` INTEGER NOT NULL,
  `id_usuario` INTEGER NOT NULL,
  `data_pedido` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` VARCHAR(20) NOT NULL DEFAULT 'Rascunho',
  `data_recebimento` DATETIME NULL,
  `valor_total` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `observacao` VARCHAR(255),
  CONSTRAINT `ck_compra_status` CHECK (status IN ('Rascunho','Pedida','Recebida','Cancelada')),
  CONSTRAINT `ck_compra_total` CHECK (valor_total >= 0),
  CONSTRAINT `ck_compra_receb` CHECK (status <> 'Recebida' OR data_recebimento IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `item_compra` (
  `id_compra` INTEGER NOT NULL,
  `id_produto` INTEGER NOT NULL,
  `quantidade` DECIMAL(10,3) NOT NULL,
  `custo_unitario` DECIMAL(10,2) NOT NULL,
  CONSTRAINT `ck_icompra_qtd` CHECK (quantidade > 0),
  CONSTRAINT `ck_icompra_custo` CHECK (custo_unitario >= 0),
  PRIMARY KEY (`id_compra`, `id_produto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `venda` (
  `id_venda` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_usuario` INTEGER NOT NULL,
  `id_cliente` INTEGER,
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` VARCHAR(20) NOT NULL DEFAULT 'Aberta',
  `valor_total` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `forma_pagamento` VARCHAR(30),
  CONSTRAINT `ck_venda_status` CHECK (status IN ('Aberta','Concluida','Cancelada')),
  CONSTRAINT `ck_venda_forma` CHECK (forma_pagamento IS NULL OR forma_pagamento IN ('Pix','Credito','Debito','Dinheiro')),
  CONSTRAINT `ck_venda_total` CHECK (valor_total >= 0),
  CONSTRAINT `ck_venda_forma_concluida` CHECK (status <> 'Concluida' OR forma_pagamento IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `item_venda` (
  `id_venda` INTEGER NOT NULL,
  `id_produto` INTEGER NOT NULL,
  `quantidade` DECIMAL(10,3) NOT NULL,
  `preco_unitario` DECIMAL(10,2) NOT NULL,
  `desconto_unitario` DECIMAL(10,2),
  CONSTRAINT `ck_ivenda_qtd` CHECK (quantidade > 0),
  CONSTRAINT `ck_ivenda_preco` CHECK (preco_unitario >= 0),
  CONSTRAINT `ck_ivenda_desc` CHECK (desconto_unitario IS NULL OR (desconto_unitario >= 0 AND desconto_unitario <= preco_unitario)),
  PRIMARY KEY (`id_venda`, `id_produto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `conta_pagar` (
  `id_conta` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_fornecedor` INTEGER,
  `id_compra` INTEGER,
  `id_usuario` INTEGER NOT NULL,
  `descricao` VARCHAR(150) NOT NULL,
  `categoria` VARCHAR(40) NOT NULL,
  `valor` DECIMAL(10,2) NOT NULL,
  `data_vencimento` DATE NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'Aberta',
  `data_baixa` DATETIME NULL,
  CONSTRAINT `ck_conta_valor` CHECK (valor > 0),
  CONSTRAINT `ck_conta_status` CHECK (status IN ('Aberta','Paga','Atrasada','Cancelada')),
  CONSTRAINT `ck_conta_baixa` CHECK (status <> 'Paga' OR data_baixa IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `registro_higienizacao` (
  `id_registro` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `id_usuario` INTEGER NOT NULL,
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `item_area` VARCHAR(100) NOT NULL,
  `etapa` VARCHAR(20) NOT NULL,
  `metodo` VARCHAR(120) NOT NULL,
  `produto_lote` VARCHAR(100),
  `referencia_ciclo` VARCHAR(100),
  `resultado` VARCHAR(20) NOT NULL,
  `observacao` VARCHAR(255),
  CONSTRAINT `ck_higi_etapa` CHECK (etapa IN ('Limpeza','Desinfeccao','Esterilizacao','Descarte')),
  CONSTRAINT `ck_higi_resultado` CHECK (resultado IN ('Concluido','Reprovado','Refeito'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `fechamento_caixa` (
  `id_fechamento` INTEGER PRIMARY KEY AUTO_INCREMENT,
  `id_usuario` INTEGER NOT NULL,
  `aberto_em` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fechado_em` DATETIME NULL,
  `saldo_abertura` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `status` VARCHAR(15) NOT NULL DEFAULT 'Aberto',
  -- Substitui o índice parcial do PostgreSQL (UNIQUE ... WHERE status = 'Aberto'):
  -- vale 1 quando aberto e NULL quando fechado; o UNIQUE ignora NULLs.
  `flag_aberto` TINYINT GENERATED ALWAYS AS (IF(`status` = 'Aberto', 1, NULL)) STORED,
  CONSTRAINT `ck_fech_status` CHECK (status IN ('Aberto','Fechado')),
  CONSTRAINT `ck_fech_saldo` CHECK (saldo_abertura >= 0),
  CONSTRAINT `ck_fech_datas` CHECK ((status = 'Aberto'  AND fechado_em IS NULL) OR
        (status = 'Fechado' AND fechado_em IS NOT NULL AND fechado_em >= aberto_em))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `fechamento_forma` (
  `id_fechamento` INTEGER NOT NULL,
  `forma_pagamento` VARCHAR(20) NOT NULL,
  `valor_esperado` DECIMAL(10,2) NOT NULL,
  `valor_conferido` DECIMAL(10,2) NOT NULL,
  `diferenca` DECIMAL(10,2),
  CONSTRAINT `ck_ff_forma` CHECK (forma_pagamento IN ('Dinheiro','Pix','Credito','Debito')),
  PRIMARY KEY (`id_fechamento`, `forma_pagamento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `movimento_caixa` (
  `id_movimento` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `id_usuario` INTEGER NOT NULL,
  `id_pagamento` INTEGER,
  `id_venda` INTEGER,
  `id_conta` INTEGER,
  `id_fechamento` INTEGER,
  `tipo` VARCHAR(20) NOT NULL,
  `forma_pagamento` VARCHAR(20) NOT NULL,
  `valor` DECIMAL(10,2) NOT NULL,
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `motivo` VARCHAR(255),
  CONSTRAINT `ck_mcx_tipo` CHECK (tipo IN ('Entrada','Saida','Estorno','Ajuste')),
  CONSTRAINT `ck_mcx_forma` CHECK (forma_pagamento IN ('Dinheiro','Pix','Credito','Debito','Nao_aplicavel')),
  CONSTRAINT `ck_mcx_valor` CHECK (valor > 0),
  CONSTRAINT `ck_mcx_origem_unica` CHECK ((id_pagamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_conta IS NOT NULL) <= 1),
  CONSTRAINT `ck_mcx_origem_obrig` CHECK (tipo = 'Ajuste' OR
        (id_pagamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_conta IS NOT NULL) = 1),
  CONSTRAINT `ck_mcx_motivo` CHECK (tipo NOT IN ('Ajuste','Estorno') OR motivo IS NOT NULL)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `movimento_estoque` (
  `id_mov_estoque` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `id_produto` INTEGER NOT NULL,
  `id_usuario` INTEGER NOT NULL,
  `id_compra` INTEGER,
  `id_produto_compra` INTEGER,
  `id_venda` INTEGER,
  `id_produto_venda` INTEGER,
  `id_registro_higienizacao` BIGINT,
  `tipo` VARCHAR(15) NOT NULL,
  `quantidade` DECIMAL(10,3) NOT NULL,
  `custo_unitario` DECIMAL(10,4),
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `motivo` VARCHAR(255),
  CONSTRAINT `ck_mest_tipo` CHECK (tipo IN ('Entrada','Saida','Ajuste')),
  CONSTRAINT `ck_mest_qtd` CHECK (quantidade > 0),
  CONSTRAINT `ck_mest_custo` CHECK (custo_unitario IS NULL OR custo_unitario >= 0),
  CONSTRAINT `ck_mest_par_compra` CHECK ((id_compra IS NULL) = (id_produto_compra IS NULL)),
  CONSTRAINT `ck_mest_par_venda` CHECK ((id_venda IS NULL) = (id_produto_venda IS NULL)),
  CONSTRAINT `ck_mest_prod_compra` CHECK (id_produto_compra IS NULL OR id_produto_compra = id_produto),
  CONSTRAINT `ck_mest_prod_venda` CHECK (id_produto_venda IS NULL OR id_produto_venda = id_produto),
  CONSTRAINT `ck_mest_origem` CHECK ((tipo = 'Entrada' AND id_compra IS NOT NULL AND id_venda IS NULL AND id_registro_higienizacao IS NULL) OR
        (tipo = 'Saida'   AND id_compra IS NULL AND
            ((id_venda IS NOT NULL) + (id_registro_higienizacao IS NOT NULL) = 1)) OR
        (tipo = 'Ajuste'  AND id_compra IS NULL AND id_venda IS NULL AND id_registro_higienizacao IS NULL
                          AND motivo IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `documento_fiscal` (
  `id_documento` BIGINT PRIMARY KEY AUTO_INCREMENT,
  `id_agendamento` INTEGER,
  `id_venda` INTEGER,
  `id_compra` INTEGER,
  `tipo` VARCHAR(30) NOT NULL,
  `numero` VARCHAR(30) NOT NULL,
  `serie` VARCHAR(20),
  `chave_acesso` VARCHAR(60),
  `emitido_em` DATETIME NOT NULL,
  `status` VARCHAR(20) NOT NULL,
  `localizador_arquivo` VARCHAR(255),
  CONSTRAINT `ck_df_status` CHECK (status IN ('Autorizado','Pendente','Cancelado','Recebido')),
  CONSTRAINT `ck_df_origem` CHECK ((id_agendamento IS NOT NULL) + (id_venda IS NOT NULL) + (id_compra IS NOT NULL) = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------- Índices

CREATE UNIQUE INDEX `uq_usuario_login` ON `usuario_sistema` (`identificador_login`);
CREATE INDEX `ix_usuario_ativo` ON `usuario_sistema` (`ativo`);

CREATE INDEX `ix_log_componente_data` ON `log_auditoria` (`componente`, `data_hora`);
CREATE INDEX `ix_log_usuario_data` ON `log_auditoria` (`id_usuario`, `data_hora`);
CREATE INDEX `ix_log_principal_data` ON `log_auditoria` (`principal_sgbd`, `data_hora`);
CREATE INDEX `ix_log_recurso_data` ON `log_auditoria` (`recurso`, `data_hora`);
CREATE INDEX `ix_log_expurgo` ON `log_auditoria` (`data_expurgo_prevista`);

CREATE INDEX `ix_cliente_telefone` ON `cliente` (`telefone`);

CREATE INDEX `ix_profissional_ativo` ON `profissional` (`ativo`);

-- Unicidade case-insensitive já é garantida pela collation padrão (utf8mb4_0900_ai_ci).
-- MySQL não tem índice parcial; se o nome só devia ser único entre serviços ativos,
-- é preciso uma coluna gerada (como em fechamento_caixa).
CREATE UNIQUE INDEX `uq_servico_nome_ativo` ON `servico` (`nome`);
CREATE INDEX `ix_servico_ativo` ON `servico` (`ativo`);

CREATE INDEX `ix_extra_ativo` ON `servico_extra` (`ativo`);

CREATE INDEX `ix_regra_tipo_dia_vig` ON `regra_calendario` (`tipo_regra`, `dia_semana`, `vigencia_inicio`);
CREATE INDEX `ix_regra_data` ON `regra_calendario` (`data_especifica`);
CREATE INDEX `ix_regra_ativo` ON `regra_calendario` (`ativo`);
CREATE UNIQUE INDEX `uq_regra_excecao_data` ON `regra_calendario` (`data_especifica`);
CREATE UNIQUE INDEX `uq_regra_semanal_vig` ON `regra_calendario` (`dia_semana`, `vigencia_inicio`);

CREATE INDEX `ix_agend_prof_data_hora` ON `agendamento` (`id_profissional`, `data`, `hora_inicio`);
CREATE INDEX `ix_agend_cliente` ON `agendamento` (`id_cliente`);
CREATE INDEX `ix_agend_regra` ON `agendamento` (`id_regra_calendario`);
CREATE INDEX `ix_agend_status` ON `agendamento` (`status`);

CREATE INDEX `ix_ags_servico` ON `agendamento_servico` (`id_servico`);

CREATE INDEX `ix_age_extra` ON `agendamento_extra` (`id_extra`);

CREATE INDEX `ix_pag_agend_status` ON `pagamento` (`id_agendamento`, `status`);
CREATE INDEX `ix_pag_status_criado` ON `pagamento` (`status`, `criado_em`);
CREATE INDEX `ix_pag_origem` ON `pagamento` (`id_pagamento_origem`);
CREATE UNIQUE INDEX `uq_pag_referencia_provedor` ON `pagamento` (`referencia_provedor`);
CREATE UNIQUE INDEX `uq_pag_idempotencia` ON `pagamento` (`chave_idempotencia`);

CREATE UNIQUE INDEX `uq_avaliacao_agend` ON `avaliacao` (`id_agendamento`);

CREATE UNIQUE INDEX `uq_produto_sku` ON `produto` (`sku`);
CREATE INDEX `ix_produto_ativo_nome` ON `produto` (`ativo`, `nome`);

CREATE UNIQUE INDEX `uq_fornecedor_documento` ON `fornecedor` (`documento_fiscal`);

CREATE INDEX `ix_compra_fornecedor` ON `compra` (`id_fornecedor`);
CREATE INDEX `ix_compra_usuario` ON `compra` (`id_usuario`);
CREATE INDEX `ix_compra_status` ON `compra` (`status`);

CREATE INDEX `ix_icompra_produto` ON `item_compra` (`id_produto`);

CREATE INDEX `ix_venda_usuario` ON `venda` (`id_usuario`);
CREATE INDEX `ix_venda_cliente` ON `venda` (`id_cliente`);
CREATE INDEX `ix_venda_data` ON `venda` (`data_hora`);

CREATE INDEX `ix_ivenda_produto` ON `item_venda` (`id_produto`);

CREATE INDEX `ix_conta_fornecedor` ON `conta_pagar` (`id_fornecedor`);
CREATE INDEX `ix_conta_compra` ON `conta_pagar` (`id_compra`);
CREATE INDEX `ix_conta_vencimento` ON `conta_pagar` (`data_vencimento`, `status`);

CREATE INDEX `ix_higi_usuario_data` ON `registro_higienizacao` (`id_usuario`, `data_hora`);

CREATE INDEX `ix_fech_usuario` ON `fechamento_caixa` (`id_usuario`);
-- No máximo um caixa aberto por vez (corrige o UNIQUE em `status`, que permitiria só 1 Aberto e 1 Fechado).
CREATE UNIQUE INDEX `uq_fech_um_aberto` ON `fechamento_caixa` (`flag_aberto`);

CREATE INDEX `ix_mcx_usuario` ON `movimento_caixa` (`id_usuario`);
CREATE INDEX `ix_mcx_pagamento` ON `movimento_caixa` (`id_pagamento`);
CREATE INDEX `ix_mcx_venda` ON `movimento_caixa` (`id_venda`);
CREATE INDEX `ix_mcx_conta` ON `movimento_caixa` (`id_conta`);
CREATE INDEX `ix_mcx_fechamento` ON `movimento_caixa` (`id_fechamento`);
CREATE INDEX `ix_mcx_data` ON `movimento_caixa` (`data_hora`);
CREATE UNIQUE INDEX `uq_mcx_pagamento` ON `movimento_caixa` (`id_pagamento`);
CREATE UNIQUE INDEX `uq_mcx_venda_tipo` ON `movimento_caixa` (`id_venda`, `tipo`);

CREATE INDEX `ix_mest_prod_data` ON `movimento_estoque` (`id_produto`, `data_hora`);
CREATE INDEX `ix_mest_compra` ON `movimento_estoque` (`id_compra`);
CREATE INDEX `ix_mest_venda` ON `movimento_estoque` (`id_venda`);
CREATE INDEX `ix_mest_higi` ON `movimento_estoque` (`id_registro_higienizacao`);
CREATE UNIQUE INDEX `uq_mest_item_compra` ON `movimento_estoque` (`id_compra`, `id_produto_compra`);
CREATE UNIQUE INDEX `uq_mest_item_venda` ON `movimento_estoque` (`id_venda`, `id_produto_venda`);

CREATE INDEX `ix_df_agend` ON `documento_fiscal` (`id_agendamento`);
CREATE INDEX `ix_df_venda` ON `documento_fiscal` (`id_venda`);
CREATE INDEX `ix_df_compra` ON `documento_fiscal` (`id_compra`);
-- Índice funcional no MySQL exige expressão entre parênteses adicionais.
CREATE UNIQUE INDEX `uq_df_tipo_serie_numero` ON `documento_fiscal` (`tipo`, (COALESCE(`serie`, '')), `numero`);
CREATE UNIQUE INDEX `uq_df_chave_acesso` ON `documento_fiscal` (`chave_acesso`);

-- ------------------------------------------------------------ Comentários

ALTER TABLE `usuario_sistema` COMMENT = 'Identidade individual (ou conta técnica) que opera o sistema. Não armazena senha, hash, token ou segredo.';
ALTER TABLE `log_auditoria` COMMENT = 'Trilha append-only. Não gravar senhas, tokens, dados de cartão nem snapshots de registros.';
ALTER TABLE `cliente` COMMENT = 'Dado pessoal (LGPD): acesso restrito. Marketing é opt-in e independente do atendimento.';
ALTER TABLE `regra_calendario` COMMENT = 'Expediente semanal e exceções (feriados). Exceção de data prevalece sobre a regra semanal.';
ALTER TABLE `pagamento` COMMENT = 'Tentativas, capturas e estornos. Nunca armazenar número de cartão, CVV, senha ou token.';
ALTER TABLE `produto` COMMENT = 'Sem saldo editável: o saldo é a soma dos movimentos em movimento_estoque.';
ALTER TABLE `documento_fiscal` COMMENT = 'Referência ao documento fiscal; não calcula tributos. Arquivo/XML em repositório protegido.';

-- ------------------------------------------------------------ Chaves estrangeiras

ALTER TABLE `posts` ADD CONSTRAINT `user_posts` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);
ALTER TABLE `follows` ADD FOREIGN KEY (`following_user_id`) REFERENCES `users` (`id`);
ALTER TABLE `follows` ADD FOREIGN KEY (`followed_user_id`) REFERENCES `users` (`id`);

ALTER TABLE `log_auditoria` ADD CONSTRAINT `fk_log_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);

ALTER TABLE `agendamento` ADD CONSTRAINT `fk_agend_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `cliente` (`id_cliente`);
ALTER TABLE `agendamento` ADD CONSTRAINT `fk_agend_prof` FOREIGN KEY (`id_profissional`) REFERENCES `profissional` (`id_profissional`);
ALTER TABLE `agendamento` ADD CONSTRAINT `fk_agend_regra` FOREIGN KEY (`id_regra_calendario`) REFERENCES `regra_calendario` (`id_regra_calendario`);

ALTER TABLE `agendamento_servico` ADD CONSTRAINT `fk_ags_agend` FOREIGN KEY (`id_agendamento`) REFERENCES `agendamento` (`id_agendamento`);
ALTER TABLE `agendamento_servico` ADD CONSTRAINT `fk_ags_servico` FOREIGN KEY (`id_servico`) REFERENCES `servico` (`id_servico`);

ALTER TABLE `agendamento_extra` ADD CONSTRAINT `fk_age_agend` FOREIGN KEY (`id_agendamento`) REFERENCES `agendamento` (`id_agendamento`);
ALTER TABLE `agendamento_extra` ADD CONSTRAINT `fk_age_extra` FOREIGN KEY (`id_extra`) REFERENCES `servico_extra` (`id_extra`);

ALTER TABLE `pagamento` ADD CONSTRAINT `fk_pag_agend` FOREIGN KEY (`id_agendamento`) REFERENCES `agendamento` (`id_agendamento`);
ALTER TABLE `pagamento` ADD CONSTRAINT `fk_pag_origem` FOREIGN KEY (`id_pagamento_origem`) REFERENCES `pagamento` (`id_pagamento`);

ALTER TABLE `avaliacao` ADD CONSTRAINT `fk_aval_agend` FOREIGN KEY (`id_agendamento`) REFERENCES `agendamento` (`id_agendamento`);

ALTER TABLE `compra` ADD CONSTRAINT `fk_compra_fornecedor` FOREIGN KEY (`id_fornecedor`) REFERENCES `fornecedor` (`id_fornecedor`);
ALTER TABLE `compra` ADD CONSTRAINT `fk_compra_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);

ALTER TABLE `item_compra` ADD CONSTRAINT `fk_icompra_compra` FOREIGN KEY (`id_compra`) REFERENCES `compra` (`id_compra`);
ALTER TABLE `item_compra` ADD CONSTRAINT `fk_icompra_produto` FOREIGN KEY (`id_produto`) REFERENCES `produto` (`id_produto`);

ALTER TABLE `venda` ADD CONSTRAINT `fk_venda_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);
ALTER TABLE `venda` ADD CONSTRAINT `fk_venda_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `cliente` (`id_cliente`);

ALTER TABLE `item_venda` ADD CONSTRAINT `fk_ivenda_venda` FOREIGN KEY (`id_venda`) REFERENCES `venda` (`id_venda`);
ALTER TABLE `item_venda` ADD CONSTRAINT `fk_ivenda_produto` FOREIGN KEY (`id_produto`) REFERENCES `produto` (`id_produto`);

ALTER TABLE `conta_pagar` ADD CONSTRAINT `fk_conta_fornecedor` FOREIGN KEY (`id_fornecedor`) REFERENCES `fornecedor` (`id_fornecedor`);
ALTER TABLE `conta_pagar` ADD CONSTRAINT `fk_conta_compra` FOREIGN KEY (`id_compra`) REFERENCES `compra` (`id_compra`);
ALTER TABLE `conta_pagar` ADD CONSTRAINT `fk_conta_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);

ALTER TABLE `registro_higienizacao` ADD CONSTRAINT `fk_higi_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);

ALTER TABLE `fechamento_caixa` ADD CONSTRAINT `fk_fech_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);

ALTER TABLE `fechamento_forma` ADD CONSTRAINT `fk_ff_fechamento` FOREIGN KEY (`id_fechamento`) REFERENCES `fechamento_caixa` (`id_fechamento`);

ALTER TABLE `movimento_caixa` ADD CONSTRAINT `fk_mcx_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);
ALTER TABLE `movimento_caixa` ADD CONSTRAINT `fk_mcx_pagamento` FOREIGN KEY (`id_pagamento`) REFERENCES `pagamento` (`id_pagamento`);
ALTER TABLE `movimento_caixa` ADD CONSTRAINT `fk_mcx_venda` FOREIGN KEY (`id_venda`) REFERENCES `venda` (`id_venda`);
ALTER TABLE `movimento_caixa` ADD CONSTRAINT `fk_mcx_conta` FOREIGN KEY (`id_conta`) REFERENCES `conta_pagar` (`id_conta`);
ALTER TABLE `movimento_caixa` ADD CONSTRAINT `fk_mcx_fechamento` FOREIGN KEY (`id_fechamento`) REFERENCES `fechamento_caixa` (`id_fechamento`);

ALTER TABLE `movimento_estoque` ADD CONSTRAINT `fk_mest_produto` FOREIGN KEY (`id_produto`) REFERENCES `produto` (`id_produto`);
ALTER TABLE `movimento_estoque` ADD CONSTRAINT `fk_mest_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario_sistema` (`id_usuario`);
ALTER TABLE `movimento_estoque` ADD CONSTRAINT `fk_mest_item_compra` FOREIGN KEY (`id_compra`, `id_produto_compra`) REFERENCES `item_compra` (`id_compra`, `id_produto`);
ALTER TABLE `movimento_estoque` ADD CONSTRAINT `fk_mest_item_venda` FOREIGN KEY (`id_venda`, `id_produto_venda`) REFERENCES `item_venda` (`id_venda`, `id_produto`);
ALTER TABLE `movimento_estoque` ADD CONSTRAINT `fk_mest_higi` FOREIGN KEY (`id_registro_higienizacao`) REFERENCES `registro_higienizacao` (`id_registro`);

ALTER TABLE `documento_fiscal` ADD CONSTRAINT `fk_df_agend` FOREIGN KEY (`id_agendamento`) REFERENCES `agendamento` (`id_agendamento`);
ALTER TABLE `documento_fiscal` ADD CONSTRAINT `fk_df_venda` FOREIGN KEY (`id_venda`) REFERENCES `venda` (`id_venda`);
ALTER TABLE `documento_fiscal` ADD CONSTRAINT `fk_df_compra` FOREIGN KEY (`id_compra`) REFERENCES `compra` (`id_compra`);

-- ------------------------------------------------------------ Dados de exemplo

-- Disable foreign key checks for INSERT
SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO `users` (`id`, `username`, `role`)
VALUES
  (0, 'Alice', 'admin'),
  (1, 'Bob', 'moderator'),
  (2, 'Candice', 'moderator'),
  (3, 'David', 'member');

INSERT INTO `follows` (`following_user_id`, `followed_user_id`, `created_at`)
VALUES
  (1, 0, '2026-01-01'),
  (3, 2, '2026-02-28');

INSERT INTO `posts` (`id`, `title`, `user_id`)
VALUES
  (0, 'Welcome to the forum!', 0),
  (1, 'Guidelines', 1),
  (2, 'Hello all!', 3);

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;
