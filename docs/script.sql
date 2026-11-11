-- ============================================================================
-- Barbearia The Family Hair — script completo MySQL 8.0.16+
-- ============================================================================
-- Executa do zero, em um banco vazio, nesta ordem:
--   PARTE 1  CREATE DATABASE e CREATE TABLE (com PK, NOT NULL, DEFAULT e CHECK)
--   PARTE 2  Índices UNIQUE e chaves estrangeiras (constraints)
--   PARTE 3  Gatilhos, eventos e visão das regras de negócio cruzadas
--   PARTE 4  INSERT INTO — carga da massa de dados fictícia
--            (o mesmo conteúdo está em docs/massa-de-dados.sql, para recarregar os dados)
--   PARTE 5  SELECT com JOIN (V01, S01, S02)
--   PARTE 6  UPDATE (U01…U03)
--   PARTE 7  DELETE (D01, D02)
--   PARTE 8  Consultas gerenciais (G01…G11) — cada uma indica o problema (P1…P3) e o processo (PN01…PN14)
--   PARTE 9  Consultas de auditoria (A01…A07) — cada uma indica a regra (RNxx) que verifica
--   PARTE 10 Testes das regras (T01…T05)
-- Requer InnoDB, utf8mb4 e MySQL 8.0.16+ (versão que aplica CHECK).
-- Os EVENTs exigem event_scheduler=ON (SET GLOBAL event_scheduler = ON; requer privilégio).
-- Para recomeçar: DROP DATABASE barbearia_the_family; e execute este arquivo de novo.

-- ============================================================================
-- PARTE 1 — CREATE DATABASE e CREATE TABLE
-- ============================================================================

SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS `barbearia_the_family`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `barbearia_the_family`;

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
  `id_usuario` INTEGER NULL,
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
  `data_atualizacao` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  `ativo` BOOLEAN NOT NULL DEFAULT TRUE,
  `aceita_marketing` BOOLEAN NOT NULL DEFAULT FALSE,
  `data_consentimento_marketing` DATETIME NULL,
  `data_revogacao_marketing` DATETIME NULL,
  -- Somente dígitos; remove o DDI 55 quando presente, para '+55 11 98520-6485' e '11985206485' colidirem no UNIQUE.
  `telefone_normalizado` VARCHAR(20) GENERATED ALWAYS AS
      (CASE WHEN REGEXP_REPLACE(telefone, '[^0-9]', '') REGEXP '^55[0-9]{10,11}$'
            THEN SUBSTRING(REGEXP_REPLACE(telefone, '[^0-9]', ''), 3)
            ELSE REGEXP_REPLACE(telefone, '[^0-9]', '') END) STORED,
  CONSTRAINT `ck_cliente_email` CHECK (email IS NULL OR email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
  CONSTRAINT `ck_cliente_consent` CHECK (aceita_marketing = FALSE OR
        (data_consentimento_marketing IS NOT NULL AND data_revogacao_marketing IS NULL)),
  CONSTRAINT `ck_cliente_revogacao` CHECK (data_revogacao_marketing IS NULL OR
        (data_consentimento_marketing IS NOT NULL AND aceita_marketing = FALSE
         AND data_revogacao_marketing >= data_consentimento_marketing)),
  CONSTRAINT `ck_cliente_telefone` CHECK (CHAR_LENGTH(telefone_normalizado) BETWEEN 10 AND 11)
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
  `nome_ativo` VARCHAR(100) GENERATED ALWAYS AS
      (IF(ativo, LOWER(nome), NULL)) STORED,
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
  CONSTRAINT `ck_regra_horarios` CHECK ((situacao = 'ABERTO' AND hora_abertura IS NOT NULL AND hora_fechamento IS NOT NULL
                              AND hora_fechamento > hora_abertura) OR
        (situacao = 'FECHADO' AND hora_abertura IS NULL AND hora_fechamento IS NULL))
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
  `forma_baixa` VARCHAR(20) NULL,
  CONSTRAINT `ck_conta_valor` CHECK (valor > 0),
  CONSTRAINT `ck_conta_status` CHECK (status IN ('Aberta','Paga','Atrasada','Cancelada')),
  CONSTRAINT `ck_conta_forma` CHECK (forma_baixa IS NULL OR forma_baixa IN ('Dinheiro','Pix','Credito','Debito')),
  CONSTRAINT `ck_conta_baixa` CHECK (status <> 'Paga' OR (data_baixa IS NOT NULL AND forma_baixa IS NOT NULL))
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
  `diferenca` DECIMAL(10,2) GENERATED ALWAYS AS (`valor_conferido` - `valor_esperado`) STORED,
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
  `direcao_ajuste` VARCHAR(10),
  `quantidade` DECIMAL(10,3) NOT NULL,
  `custo_unitario` DECIMAL(10,4),
  `data_hora` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `motivo` VARCHAR(255),
  CONSTRAINT `ck_mest_tipo` CHECK (tipo IN ('Entrada','Saida','Ajuste')),
  CONSTRAINT `ck_mest_direcao` CHECK ((tipo = 'Ajuste' AND direcao_ajuste IN ('Entrada','Saida')) OR
                                      (tipo <> 'Ajuste' AND direcao_ajuste IS NULL)),
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

-- ============================================================================
-- PARTE 2 — Índices UNIQUE e chaves estrangeiras
-- ============================================================================
-- ---------------------------------------------------------------- Índices

CREATE UNIQUE INDEX `uq_usuario_login` ON `usuario_sistema` (`identificador_login`);

CREATE INDEX `ix_log_componente_data` ON `log_auditoria` (`componente`, `data_hora`);
CREATE INDEX `ix_log_usuario_data` ON `log_auditoria` (`id_usuario`, `data_hora`);
CREATE INDEX `ix_log_principal_data` ON `log_auditoria` (`principal_sgbd`, `data_hora`);
CREATE INDEX `ix_log_recurso_data` ON `log_auditoria` (`recurso`, `data_hora`);
CREATE INDEX `ix_log_expurgo` ON `log_auditoria` (`data_expurgo_prevista`);

CREATE UNIQUE INDEX `uq_cliente_telefone_normalizado` ON `cliente` (`telefone_normalizado`);


-- A coluna gerada fica NULL para inativos; UNIQUE permite vários NULLs.
CREATE UNIQUE INDEX `uq_servico_nome_ativo` ON `servico` (`nome_ativo`);


CREATE INDEX `ix_regra_tipo_dia_vig` ON `regra_calendario` (`tipo_regra`, `dia_semana`, `vigencia_inicio`);
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
CREATE UNIQUE INDEX `uq_mcx_conta_tipo` ON `movimento_caixa` (`id_conta`, `tipo`);
CREATE INDEX `ix_mcx_fechamento` ON `movimento_caixa` (`id_fechamento`);
CREATE INDEX `ix_mcx_data` ON `movimento_caixa` (`data_hora`);
CREATE UNIQUE INDEX `uq_mcx_pagamento` ON `movimento_caixa` (`id_pagamento`);
CREATE UNIQUE INDEX `uq_mcx_venda_tipo` ON `movimento_caixa` (`id_venda`, `tipo`);

CREATE INDEX `ix_mest_prod_data` ON `movimento_estoque` (`id_produto`, `data_hora`);
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
ALTER TABLE `log_auditoria` COMMENT = 'Trilha append-only (UPDATE bloqueado; DELETE só após data_expurgo_prevista). id_usuario nulo = login inexistente ou principal do SGBD. Não gravar senhas, tokens, dados de cartão nem snapshots.';
ALTER TABLE `cliente` COMMENT = 'Dado pessoal (LGPD): acesso restrito. Marketing é opt-in e independente do atendimento.';
ALTER TABLE `regra_calendario` COMMENT = 'Expediente semanal e exceções (feriados). Exceção de data prevalece sobre a regra semanal.';
ALTER TABLE `pagamento` COMMENT = 'Tentativas, capturas e estornos. Nunca armazenar número de cartão, CVV, senha ou token.';
ALTER TABLE `produto` COMMENT = 'Sem saldo editável: o saldo é a soma dos movimentos em movimento_estoque.';
ALTER TABLE `documento_fiscal` COMMENT = 'Referência ao documento fiscal; não calcula tributos. Arquivo/XML em repositório protegido.';

-- ------------------------------------------------------------ Chaves estrangeiras

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

-- ============================================================================
-- PARTE 3 — Gatilhos, eventos e visão (regras cruzadas)
-- ============================================================================
-- ------------------------------------------------------------ Regras cruzadas
-- CHECK e FK não alcançam relações entre linhas/tabelas. Estes gatilhos
-- implementam as regras operacionais declaradas no README e no dicionário.
--
-- Convenções desta seção:
--  * Estados finais são imutáveis (agendamento, pagamento, venda, compra, conta).
--  * Transições de status seguem uma máquina de estados explícita.
--  * Regras que dependem de "ler e depois gravar" travam a linha-pai com
--    SELECT ... FOR UPDATE, porque um SELECT simples não impede que duas
--    transações concorrentes passem juntas pela mesma validação.

DELIMITER $$

-- ----------------------------------------------------------------- Agenda

-- Valida expediente, exceção de calendário e conflito de horário.
-- Trava a linha do profissional para serializar reservas concorrentes.
CREATE PROCEDURE `sp_validar_agenda`(
  IN p_id_agendamento  INT,
  IN p_id_profissional INT,
  IN p_data            DATE,
  IN p_hora_inicio     TIME,
  IN p_hora_fim        TIME,
  IN p_id_regra        INT
)
BEGIN
  DECLARE v_trava INT DEFAULT 0;
  DECLARE v_ok    INT DEFAULT 0;
  DECLARE v_tipo  VARCHAR(15) DEFAULT NULL;
  DECLARE v_conflitos INT DEFAULT 0;

  SELECT COUNT(*) INTO v_trava
    FROM `profissional` WHERE id_profissional = p_id_profissional FOR UPDATE;

  SELECT COUNT(*), MAX(r.tipo_regra) INTO v_ok, v_tipo
    FROM `regra_calendario` r
   WHERE r.id_regra_calendario = p_id_regra
     AND r.ativo = TRUE
     AND r.situacao = 'ABERTO'
     AND p_data >= r.vigencia_inicio
     AND (r.vigencia_fim IS NULL OR p_data <= r.vigencia_fim)
     AND ((r.tipo_regra = 'SEMANAL' AND DAYOFWEEK(p_data) = IF(r.dia_semana = 7, 1, r.dia_semana + 1))
          OR (r.tipo_regra = 'EXCECAO' AND p_data = r.data_especifica))
     AND p_hora_inicio >= r.hora_abertura AND p_hora_fim <= r.hora_fechamento;
  IF v_ok = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agendamento fora da regra de calendário ativa.';
  END IF;

  -- A exceção de data prevalece sobre a regra semanal: não vale apontar para a semanal.
  IF v_tipo = 'SEMANAL' AND EXISTS (
       SELECT 1 FROM `regra_calendario` e
        WHERE e.tipo_regra = 'EXCECAO' AND e.ativo = TRUE AND e.data_especifica = p_data) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Existe exceção de calendário para a data; use a regra de exceção.';
  END IF;

  -- Pendente com prazo vencido não segura o horário (RN18), mesmo antes do evento de expiração rodar.
  -- FOR SHARE = leitura corrente: enxerga o último dado confirmado, não o snapshot do comando em andamento.
  -- Sem isso, a reserva que esperou a trava acima não enxergaria a reserva concorrente recém-confirmada.
  SELECT COUNT(*) INTO v_conflitos FROM `agendamento` a
   WHERE a.id_profissional = p_id_profissional AND a.data = p_data
     AND (p_id_agendamento IS NULL OR a.id_agendamento <> p_id_agendamento)
     AND a.status <> 'Cancelado'
     AND NOT (a.status = 'Aguardando_pagamento' AND a.expira_em <= NOW())
     AND p_hora_inicio < a.hora_fim AND p_hora_fim > a.hora_inicio
     FOR SHARE;
  IF v_conflitos > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Profissional já possui agendamento sobreposto.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_bi`
BEFORE INSERT ON `agendamento`
FOR EACH ROW
BEGIN
  IF NEW.status <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Novo agendamento deve iniciar aguardando pagamento.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM `cliente` WHERE id_cliente = NEW.id_cliente AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente inexistente ou inativo.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM `profissional` WHERE id_profissional = NEW.id_profissional AND ativo = TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Profissional inexistente ou inativo.';
  END IF;
  IF NEW.expira_em IS NULL THEN
    SET NEW.expira_em = NOW() + INTERVAL 10 MINUTE;  -- RN18 (proposta configurável)
  END IF;
  CALL sp_validar_agenda(NULL, NEW.id_profissional, NEW.data, NEW.hora_inicio, NEW.hora_fim, NEW.id_regra_calendario);
END$$

CREATE TRIGGER `trg_agendamento_bu`
BEFORE UPDATE ON `agendamento`
FOR EACH ROW
BEGIN
  DECLARE v_itens INT DEFAULT 0;
  DECLARE v_total DECIMAL(10,2) DEFAULT 0;
  DECLARE v_pago  DECIMAL(10,2) DEFAULT 0;
  DECLARE v_dur   INT DEFAULT 0;

  -- Estados finais: só observação pode mudar.
  IF OLD.status IN ('Concluido','Cancelado','Faltou') AND
     (NEW.status <> OLD.status
      OR NEW.id_cliente <> OLD.id_cliente
      OR NEW.id_profissional <> OLD.id_profissional
      OR NEW.id_regra_calendario <> OLD.id_regra_calendario
      OR NEW.data <> OLD.data
      OR NEW.hora_inicio <> OLD.hora_inicio
      OR NEW.hora_fim <> OLD.hora_fim) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agendamento em estado final não pode ser alterado.';
  END IF;

  -- Máquina de estados.
  IF NEW.status <> OLD.status AND NOT (
       (OLD.status = 'Aguardando_pagamento' AND NEW.status IN ('Confirmado','Cancelado')) OR
       (OLD.status = 'Confirmado'           AND NEW.status IN ('Concluido','Cancelado','Faltou'))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transição de status de agendamento inválida.';
  END IF;

  -- Remarcação (mudança de profissional/data/hora/regra) ou confirmação revalidam calendário e conflito.
  IF NEW.status IN ('Aguardando_pagamento','Confirmado') AND (
       NEW.id_profissional <> OLD.id_profissional OR NEW.id_regra_calendario <> OLD.id_regra_calendario
       OR NEW.data <> OLD.data OR NEW.hora_inicio <> OLD.hora_inicio OR NEW.hora_fim <> OLD.hora_fim
       OR (OLD.status = 'Aguardando_pagamento' AND NEW.status = 'Confirmado')) THEN
    CALL sp_validar_agenda(OLD.id_agendamento, NEW.id_profissional, NEW.data, NEW.hora_inicio, NEW.hora_fim, NEW.id_regra_calendario);
  END IF;

  -- Confirmação: serviço principal, duração coerente e pagamento integral.
  IF OLD.status = 'Aguardando_pagamento' AND NEW.status = 'Confirmado' THEN
    SELECT COUNT(*) INTO v_itens FROM `agendamento_servico`
      WHERE id_agendamento = NEW.id_agendamento;
    SELECT COALESCE(SUM(preco_contratado), 0), COALESCE(SUM(duracao_contratada), 0) INTO v_total, v_dur
      FROM (SELECT preco_contratado, duracao_contratada FROM `agendamento_servico` WHERE id_agendamento = NEW.id_agendamento
            UNION ALL
            SELECT preco_contratado, duracao_contratada FROM `agendamento_extra` WHERE id_agendamento = NEW.id_agendamento) itens;
    SELECT COALESCE(SUM(CASE WHEN tipo_operacao = 'Cobranca' THEN valor ELSE -valor END), 0) INTO v_pago
      FROM `pagamento` WHERE id_agendamento = NEW.id_agendamento AND status = 'Pago';
    IF v_itens = 0 OR v_pago < v_total THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Confirmação exige serviço principal e pagamento integral aprovado.';
    END IF;
    IF TIME_TO_SEC(TIMEDIFF(NEW.hora_fim, NEW.hora_inicio)) / 60 <> v_dur THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duração do agendamento deve ser igual à soma das durações contratadas.';
    END IF;
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_servico_bi`
BEFORE INSERT ON `agendamento_servico`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = NEW.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Serviços só podem ser alterados antes da confirmação.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_servico_bu`
BEFORE UPDATE ON `agendamento_servico`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = OLD.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Serviços confirmados não podem ser alterados.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_servico_bd`
BEFORE DELETE ON `agendamento_servico`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = OLD.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Serviços confirmados não podem ser removidos.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_extra_bi`
BEFORE INSERT ON `agendamento_extra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = NEW.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Extras só podem ser alterados antes da confirmação.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_extra_bu`
BEFORE UPDATE ON `agendamento_extra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = OLD.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Extras confirmados não podem ser alterados.';
  END IF;
END$$

CREATE TRIGGER `trg_agendamento_extra_bd`
BEFORE DELETE ON `agendamento_extra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = OLD.id_agendamento) <> 'Aguardando_pagamento' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Extras confirmados não podem ser removidos.';
  END IF;
END$$

CREATE TRIGGER `trg_avaliacao_bi`
BEFORE INSERT ON `avaliacao`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `agendamento` WHERE id_agendamento = NEW.id_agendamento) <> 'Concluido' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Avaliação permitida somente após atendimento concluído.';
  END IF;
END$$

-- --------------------------------------------------------------- Pagamento

CREATE TRIGGER `trg_pagamento_bi`
BEFORE INSERT ON `pagamento`
FOR EACH ROW
BEGIN
  DECLARE v_origem_ok INT DEFAULT 0;
  DECLARE v_estornado DECIMAL(10,2) DEFAULT 0;
  DECLARE v_origem_valor DECIMAL(10,2) DEFAULT 0;
  DECLARE v_trava INT DEFAULT 0;

  IF NEW.tipo_operacao = 'Estorno' THEN
    -- Trava o agendamento-pai: estornos concorrentes do mesmo agendamento passam um de cada vez.
    -- (O MySQL proíbe SELECT ... FOR UPDATE na própria tabela do gatilho, erro 1442; por isso a trava é no pai.)
    SELECT COUNT(*) INTO v_trava FROM `agendamento` WHERE id_agendamento = NEW.id_agendamento FOR UPDATE;
    SELECT COUNT(*), COALESCE(MAX(valor), 0) INTO v_origem_ok, v_origem_valor
      FROM `pagamento`
     WHERE id_pagamento = NEW.id_pagamento_origem AND id_agendamento = NEW.id_agendamento
       AND tipo_operacao = 'Cobranca' AND status = 'Pago'
       FOR SHARE;
    -- Estornos Pendentes também consomem o saldo estornável (senão dois pendentes de valor cheio passariam).
    -- FOR SHARE: leitura corrente, para enxergar o estorno que a transação concorrente acabou de confirmar.
    SELECT COALESCE(SUM(valor), 0) INTO v_estornado FROM `pagamento`
      WHERE id_pagamento_origem = NEW.id_pagamento_origem AND tipo_operacao = 'Estorno'
        AND status IN ('Pendente','Pago')
        FOR SHARE;
    IF v_origem_ok = 0 OR v_estornado + NEW.valor > v_origem_valor THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Estorno deve referenciar cobrança paga do mesmo agendamento e não pode ultrapassá-la.';
    END IF;
  END IF;
END$$

CREATE TRIGGER `trg_pagamento_bu`
BEFORE UPDATE ON `pagamento`
FOR EACH ROW
BEGIN
  IF NEW.id_agendamento <> OLD.id_agendamento
     OR NOT (NEW.id_pagamento_origem <=> OLD.id_pagamento_origem)
     OR NEW.tipo_operacao <> OLD.tipo_operacao
     OR NEW.forma_pagamento <> OLD.forma_pagamento
     OR NEW.valor <> OLD.valor THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento é imutável (agendamento, origem, tipo, forma e valor); registre novo lançamento.';
  END IF;
  IF OLD.status <> 'Pendente' AND
     (NEW.status <> OLD.status OR NOT (NEW.confirmado_em <=> OLD.confirmado_em)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento Pago/Falhou é estado final.';
  END IF;
  IF NEW.status <> OLD.status AND NEW.status NOT IN ('Pago','Falhou') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transição de status de pagamento inválida.';
  END IF;
END$$

CREATE TRIGGER `trg_pagamento_bd`
BEFORE DELETE ON `pagamento`
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento não pode ser excluído; use estorno.';
END$$

-- ------------------------------------------------------------------- Venda

CREATE TRIGGER `trg_venda_bi`
BEFORE INSERT ON `venda`
FOR EACH ROW
BEGIN
  IF NEW.status <> 'Aberta' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda deve ser criada Aberta; conclua após incluir os itens.';
  END IF;
END$$

CREATE TRIGGER `trg_venda_bu`
BEFORE UPDATE ON `venda`
FOR EACH ROW
BEGIN
  DECLARE v_itens INT DEFAULT 0;
  DECLARE v_total DECIMAL(10,2) DEFAULT 0;
  IF OLD.status <> 'Aberta' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda concluída/cancelada é imutável; corrija por estorno rastreável.';
  END IF;
  IF NEW.status = 'Concluida' THEN
    SELECT COUNT(*), COALESCE(SUM((preco_unitario - COALESCE(desconto_unitario, 0)) * quantidade), 0)
      INTO v_itens, v_total FROM `item_venda` WHERE id_venda = NEW.id_venda;
    IF v_itens = 0 OR NEW.valor_total <> ROUND(v_total, 2) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda concluída exige itens e total igual à soma dos itens.';
    END IF;
  END IF;
END$$

CREATE TRIGGER `trg_item_venda_bi`
BEFORE INSERT ON `item_venda`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `venda` WHERE id_venda = NEW.id_venda) <> 'Aberta' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens só podem ser incluídos em venda aberta.';
  END IF;
  IF (SELECT tipo_produto FROM `produto` WHERE id_produto = NEW.id_produto) = 'Insumo' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produto do tipo Insumo não pode ser vendido.';
  END IF;
END$$

CREATE TRIGGER `trg_item_venda_bu`
BEFORE UPDATE ON `item_venda`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `venda` WHERE id_venda = OLD.id_venda) <> 'Aberta'
     OR (SELECT status FROM `venda` WHERE id_venda = NEW.id_venda) <> 'Aberta' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens de venda concluída/cancelada não podem ser alterados.';
  END IF;
  IF (SELECT tipo_produto FROM `produto` WHERE id_produto = NEW.id_produto) = 'Insumo' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Produto do tipo Insumo não pode ser vendido.';
  END IF;
END$$

CREATE TRIGGER `trg_item_venda_bd`
BEFORE DELETE ON `item_venda`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `venda` WHERE id_venda = OLD.id_venda) <> 'Aberta' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens de venda concluída/cancelada não podem ser removidos.';
  END IF;
END$$

CREATE TRIGGER `trg_venda_au`
AFTER UPDATE ON `venda`
FOR EACH ROW
BEGIN
  IF NEW.status = 'Concluida' AND OLD.status <> 'Concluida' THEN
    INSERT INTO `movimento_estoque`
      (id_produto, id_usuario, id_venda, id_produto_venda, tipo, direcao_ajuste, quantidade, custo_unitario, data_hora)
    SELECT iv.id_produto, NEW.id_usuario, iv.id_venda, iv.id_produto,
           'Saida', NULL, iv.quantidade, NULL, NEW.data_hora
      FROM `item_venda` iv WHERE iv.id_venda = NEW.id_venda;
  END IF;
END$$

-- ------------------------------------------------------------------ Compra

CREATE TRIGGER `trg_compra_bi`
BEFORE INSERT ON `compra`
FOR EACH ROW
BEGIN
  IF NEW.status NOT IN ('Rascunho','Pedida') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Compra deve ser criada como Rascunho ou Pedida; receba após incluir os itens.';
  END IF;
END$$

CREATE TRIGGER `trg_compra_bu`
BEFORE UPDATE ON `compra`
FOR EACH ROW
BEGIN
  DECLARE v_itens INT DEFAULT 0;
  DECLARE v_total DECIMAL(12,5) DEFAULT 0;
  IF OLD.status IN ('Recebida','Cancelada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Compra recebida/cancelada é imutável; corrija por ajuste de estoque rastreável.';
  END IF;
  IF NEW.status = 'Recebida' THEN
    SELECT COUNT(*), COALESCE(SUM(quantidade * custo_unitario), 0) INTO v_itens, v_total
      FROM `item_compra` WHERE id_compra = NEW.id_compra;
    IF v_itens = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Compra recebida exige ao menos um item.';
    END IF;
    IF NEW.valor_total <> ROUND(v_total, 2) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total da compra deve ser igual à soma dos itens.';
    END IF;
  END IF;
END$$

CREATE TRIGGER `trg_item_compra_bi`
BEFORE INSERT ON `item_compra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `compra` WHERE id_compra = NEW.id_compra) NOT IN ('Rascunho','Pedida') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens só podem ser incluídos em compra em rascunho ou pedida.';
  END IF;
END$$

CREATE TRIGGER `trg_item_compra_bu`
BEFORE UPDATE ON `item_compra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `compra` WHERE id_compra = OLD.id_compra) NOT IN ('Rascunho','Pedida')
     OR (SELECT status FROM `compra` WHERE id_compra = NEW.id_compra) NOT IN ('Rascunho','Pedida') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens de compra recebida/cancelada não podem ser alterados.';
  END IF;
END$$

CREATE TRIGGER `trg_item_compra_bd`
BEFORE DELETE ON `item_compra`
FOR EACH ROW
BEGIN
  IF (SELECT status FROM `compra` WHERE id_compra = OLD.id_compra) NOT IN ('Rascunho','Pedida') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Itens de compra recebida/cancelada não podem ser removidos.';
  END IF;
END$$

CREATE TRIGGER `trg_compra_au`
AFTER UPDATE ON `compra`
FOR EACH ROW
BEGIN
  IF NEW.status = 'Recebida' AND OLD.status <> 'Recebida' THEN
    INSERT INTO `movimento_estoque`
      (id_produto, id_usuario, id_compra, id_produto_compra, tipo, direcao_ajuste, quantidade, custo_unitario, data_hora)
    SELECT ic.id_produto, NEW.id_usuario, ic.id_compra, ic.id_produto,
           'Entrada', NULL, ic.quantidade, ic.custo_unitario, NEW.data_recebimento
      FROM `item_compra` ic WHERE ic.id_compra = NEW.id_compra;
  END IF;
END$$

-- ------------------------------------------------------------ Contas a pagar

CREATE TRIGGER `trg_conta_pagar_bi`
BEFORE INSERT ON `conta_pagar`
FOR EACH ROW
BEGIN
  IF NEW.status NOT IN ('Aberta','Atrasada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta deve ser criada Aberta (ou Atrasada); a baixa é uma atualização.';
  END IF;
END$$

CREATE TRIGGER `trg_conta_pagar_bu`
BEFORE UPDATE ON `conta_pagar`
FOR EACH ROW
BEGIN
  IF OLD.status IN ('Paga','Cancelada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta paga/cancelada é imutável; corrija por estorno ou ajuste de caixa.';
  END IF;
  IF NEW.status <> OLD.status AND NOT (
       (OLD.status = 'Aberta'   AND NEW.status IN ('Atrasada','Paga','Cancelada')) OR
       (OLD.status = 'Atrasada' AND NEW.status IN ('Paga','Cancelada'))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transição de status de conta inválida.';
  END IF;
END$$

CREATE TRIGGER `trg_conta_pagar_au`
AFTER UPDATE ON `conta_pagar`
FOR EACH ROW
BEGIN
  IF NEW.status = 'Paga' AND OLD.status <> 'Paga' THEN
    INSERT INTO `movimento_caixa`
      (id_usuario, id_conta, tipo, forma_pagamento, valor, data_hora, motivo)
    VALUES (NEW.id_usuario, NEW.id_conta, 'Saida', NEW.forma_baixa, NEW.valor,
            NEW.data_baixa, CONCAT('Baixa da conta: ', NEW.descricao));
  END IF;
END$$

-- -------------------------------------------------------- Estoque e caixa

CREATE TRIGGER `trg_movimento_estoque_bi`
BEFORE INSERT ON `movimento_estoque`
FOR EACH ROW
BEGIN
  DECLARE v_trava INT DEFAULT 0;
  DECLARE v_saldo DECIMAL(10,3) DEFAULT 0;
  IF NEW.tipo IN ('Saida','Ajuste') AND (NEW.tipo = 'Saida' OR NEW.direcao_ajuste = 'Saida') THEN
    -- Trava o produto: duas saídas concorrentes não podem ler o mesmo saldo e ambas passarem.
    SELECT COUNT(*) INTO v_trava FROM `produto` WHERE id_produto = NEW.id_produto FOR UPDATE;
    SELECT COALESCE(SUM(CASE
      WHEN tipo = 'Entrada' OR (tipo = 'Ajuste' AND direcao_ajuste = 'Entrada') THEN quantidade
      WHEN tipo = 'Saida' OR (tipo = 'Ajuste' AND direcao_ajuste = 'Saida') THEN -quantidade
      ELSE 0 END), 0) INTO v_saldo
      FROM `movimento_estoque` WHERE id_produto = NEW.id_produto
      FOR SHARE;  -- leitura corrente: vê a saída que a transação concorrente acabou de confirmar
    IF v_saldo - NEW.quantidade < 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimento deixaria o estoque negativo.';
    END IF;
  END IF;
END$$

CREATE TRIGGER `trg_movimento_estoque_bd`
BEFORE DELETE ON `movimento_estoque`
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimento de estoque é imutável; corrija por ajuste rastreável.';
END$$

CREATE TRIGGER `trg_movimento_estoque_bu`
BEFORE UPDATE ON `movimento_estoque`
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimento de estoque é imutável; corrija por ajuste rastreável.';
END$$

CREATE TRIGGER `trg_movimento_caixa_bi`
BEFORE INSERT ON `movimento_caixa`
FOR EACH ROW
BEGIN
  IF NEW.id_fechamento IS NOT NULL AND
     (SELECT status FROM `fechamento_caixa` WHERE id_fechamento = NEW.id_fechamento) <> 'Aberto' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não é permitido incluir movimento em caixa fechado.';
  END IF;
END$$

CREATE TRIGGER `trg_movimento_caixa_bu`
BEFORE UPDATE ON `movimento_caixa`
FOR EACH ROW
BEGIN
  IF OLD.id_fechamento IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimento já consolidado não pode ser alterado.';
  END IF;
  IF NEW.id_fechamento IS NOT NULL AND
     (SELECT status FROM `fechamento_caixa` WHERE id_fechamento = NEW.id_fechamento) <> 'Aberto' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não é permitido incluir movimento em caixa fechado.';
  END IF;
END$$

CREATE TRIGGER `trg_movimento_caixa_bd`
BEFORE DELETE ON `movimento_caixa`
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Movimento de caixa não pode ser excluído; use estorno ou ajuste.';
END$$

-- ---------------------------------------------------------------- Auditoria

CREATE TRIGGER `trg_log_auditoria_bu`
BEFORE UPDATE ON `log_auditoria`
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Log de auditoria é append-only.';
END$$

-- O expurgo precisa de DELETE; só é aceito depois da data prevista.
-- Complementar com privilégio: somente a role de expurgo recebe DELETE nesta tabela.
CREATE TRIGGER `trg_log_auditoria_bd`
BEFORE DELETE ON `log_auditoria`
FOR EACH ROW
BEGIN
  IF OLD.data_expurgo_prevista > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Log só pode ser expurgado após data_expurgo_prevista.';
  END IF;
END$$

-- ------------------------------------------------------------------- Eventos

-- Libera o horário de reservas sem pagamento após o prazo (RN18).
CREATE EVENT IF NOT EXISTS `ev_expirar_reservas`
ON SCHEDULE EVERY 1 MINUTE
DO
  UPDATE `agendamento`
     SET status = 'Cancelado', cancelado_em = NOW(),
         motivo_cancelamento = 'Reserva expirada sem pagamento'
   WHERE status = 'Aguardando_pagamento' AND expira_em <= NOW()$$

CREATE EVENT IF NOT EXISTS `ev_marcar_contas_atrasadas`
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 MINUTE)
DO
  UPDATE `conta_pagar` SET status = 'Atrasada'
   WHERE status = 'Aberta' AND data_vencimento < CURRENT_DATE$$

CREATE OR REPLACE VIEW `vw_saldo_estoque` AS
SELECT p.id_produto, p.nome, p.unidade_medida,
       COALESCE(SUM(CASE
          WHEN m.tipo = 'Entrada' OR (m.tipo = 'Ajuste' AND m.direcao_ajuste = 'Entrada') THEN m.quantidade
          WHEN m.tipo = 'Saida' OR (m.tipo = 'Ajuste' AND m.direcao_ajuste = 'Saida') THEN -m.quantidade
          ELSE 0 END), 0) AS saldo,
       p.estoque_minimo
  FROM `produto` p
  LEFT JOIN `movimento_estoque` m ON m.id_produto = p.id_produto
 GROUP BY p.id_produto, p.nome, p.unidade_medida, p.estoque_minimo$$

DELIMITER ;

-- ============================================================================
-- PARTE 4 — INSERT INTO: carga da massa de dados fictícia
-- ============================================================================
-- Cópia de docs/massa-de-dados.sql. Compras e vendas são concluídas pelas
-- transições normais; os movimentos de estoque e caixa são gerados pelos gatilhos.

USE `barbearia_the_family`;
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE documento_fiscal;
TRUNCATE TABLE movimento_caixa;
TRUNCATE TABLE movimento_estoque;
TRUNCATE TABLE fechamento_forma;
TRUNCATE TABLE fechamento_caixa;
TRUNCATE TABLE conta_pagar;
TRUNCATE TABLE avaliacao;
TRUNCATE TABLE pagamento;
TRUNCATE TABLE agendamento_extra;
TRUNCATE TABLE agendamento_servico;
TRUNCATE TABLE agendamento;
TRUNCATE TABLE item_venda;
TRUNCATE TABLE venda;
TRUNCATE TABLE item_compra;
TRUNCATE TABLE compra;
TRUNCATE TABLE registro_higienizacao;
TRUNCATE TABLE regra_calendario;
TRUNCATE TABLE cliente;
TRUNCATE TABLE profissional;
TRUNCATE TABLE servico_extra;
TRUNCATE TABLE servico;
TRUNCATE TABLE produto;
TRUNCATE TABLE fornecedor;
TRUNCATE TABLE log_auditoria;
TRUNCATE TABLE usuario_sistema;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO usuario_sistema
  (nome_exibicao, identificador_login, perfil, ativo, data_criacao, data_desativacao)
VALUES
  ('Ana Beatriz Lemos','admin.ana','Administrador',TRUE,'2026-08-01 09:00:00',NULL),
  ('Camila Rocha','atend.camila','Atendimento',TRUE,'2026-08-01 09:10:00',NULL),
  ('Juliana Prado','atend.juliana','Atendimento',TRUE,'2026-08-01 09:15:00',NULL),
  ('Thiago Moreira','prof.thiago','Profissional',TRUE,'2026-08-01 09:20:00',NULL),
  ('Diego Albuquerque','prof.diego','Profissional',FALSE,'2026-08-01 09:25:00','2026-10-10 08:00:00'),
  ('Rafael Siqueira','prof.rafael','Profissional',TRUE,'2026-10-12 09:00:00',NULL);

INSERT INTO profissional (nome, especialidade, telefone, ativo) VALUES
  ('Thiago Moreira','Corte social e barba','(11) 95550-9001',TRUE),
  ('Diego Albuquerque','Degradê e acabamento','(11) 95550-9002',FALSE),
  ('Rafael Siqueira','Barboterapia e pigmentação','(11) 95550-9003',TRUE);

INSERT INTO servico (nome, descricao, duracao, preco, ativo) VALUES
  ('Corte Social','Corte tradicional na tesoura e máquina',40,50.00,TRUE),
  ('Corte Degradê','Degradê na máquina com acabamento na navalha',40,55.00,TRUE),
  ('Barba','Barba completa com toalha quente',30,35.00,TRUE),
  ('Corte + Barba','Combo corte e barba',60,80.00,TRUE),
  ('Corte Infantil','Corte para crianças até 12 anos',40,45.00,TRUE),
  ('Acabamento (Pezinho)','Contorno e acabamento do corte',15,15.00,TRUE),
  ('Corte Promoção Inauguração','Promoção encerrada',40,40.00,FALSE);

INSERT INTO servico_extra (nome, descricao, preco, duracao, ativo) VALUES
  ('Sobrancelha','Design de sobrancelha na navalha',15.00,10,TRUE),
  ('Hidratação Capilar','Hidratação rápida com máscara',25.00,15,TRUE),
  ('Pigmentação de Barba','Pigmentação para cobrir falhas',35.00,20,TRUE);

INSERT INTO cliente
  (nome, telefone, email, data_cadastro, ativo, aceita_marketing, data_consentimento_marketing)
VALUES
  ('Carlos Eduardo Nunes','(11) 95550-0001','carlos.nunes@example.com','2026-08-25 09:10:00',TRUE,TRUE,'2026-08-25 09:10:00'),
  ('Mateus Ribeiro Lopes','(11) 95550-0002','mateus.lopes@example.com','2026-08-25 09:20:00',TRUE,FALSE,NULL),
  ('Gabriel Santana Prado','(11) 95550-0003','gabriel.prado@example.com','2026-08-25 09:30:00',TRUE,TRUE,'2026-08-25 09:30:00'),
  ('Lucas Henrique Barros','(11) 95550-0004','lucas.barros@example.com','2026-08-25 09:40:00',TRUE,FALSE,NULL),
  ('Pedro Augusto Menezes','(11) 95550-0005','pedro.menezes@example.com','2026-08-25 09:50:00',TRUE,TRUE,'2026-08-25 09:50:00'),
  ('Felipe Andrade Costa','(11) 95550-0006','felipe.costa@example.com','2026-08-25 10:00:00',TRUE,FALSE,NULL),
  ('Bruno Vasconcelos Dias','(11) 95550-0007','bruno.dias@example.com','2026-08-25 10:10:00',TRUE,FALSE,NULL),
  ('Rodrigo Tavares Neto','(11) 95550-0008','rodrigo.neto@example.com','2026-08-25 10:20:00',TRUE,FALSE,NULL),
  ('André Luiz Cardoso','(11) 95550-0009','andre.cardoso@example.com','2026-08-25 10:30:00',TRUE,TRUE,'2026-08-25 10:30:00'),
  ('Marcelo Pires Fontes','(11) 95550-0010','marcelo.fontes@example.com','2026-08-25 10:40:00',TRUE,FALSE,NULL);

DELIMITER $$
CREATE PROCEDURE popular_clientes_restantes()
BEGIN
  DECLARE i INT DEFAULT 11;
  WHILE i <= 45 DO
    INSERT INTO cliente (nome, telefone, email, data_cadastro, ativo, aceita_marketing, data_consentimento_marketing)
    VALUES (CONCAT('Cliente Fictício ', i), CONCAT('(11) 95550-', LPAD(i,4,'0')),
            CONCAT('cliente',i,'@example.com'), DATE_ADD('2026-08-25 11:00:00', INTERVAL i MINUTE),
            IF(i = 40,FALSE,TRUE), IF(MOD(i,3)=0,TRUE,FALSE),
            IF(MOD(i,3)=0,DATE_ADD('2026-08-25 11:00:00', INTERVAL i MINUTE),NULL));
    SET i = i + 1;
  END WHILE;
END$$
DELIMITER ;
CALL popular_clientes_restantes();
DROP PROCEDURE popular_clientes_restantes;

INSERT INTO regra_calendario
  (tipo_regra,dia_semana,data_especifica,situacao,hora_abertura,hora_fechamento,vigencia_inicio,vigencia_fim,motivo,ativo)
VALUES
  ('SEMANAL',1,NULL,'FECHADO',NULL,NULL,'2026-01-01',NULL,'Segunda-feira fechado',TRUE),
  ('SEMANAL',2,NULL,'ABERTO','08:00:00','19:00:00','2026-01-01',NULL,NULL,TRUE),
  ('SEMANAL',3,NULL,'ABERTO','08:00:00','19:00:00','2026-01-01',NULL,NULL,TRUE),
  ('SEMANAL',4,NULL,'ABERTO','08:00:00','19:00:00','2026-01-01',NULL,NULL,TRUE),
  ('SEMANAL',5,NULL,'ABERTO','08:00:00','19:00:00','2026-01-01',NULL,NULL,TRUE),
  ('SEMANAL',6,NULL,'ABERTO','08:00:00','19:00:00','2026-01-01',NULL,NULL,TRUE),
  ('SEMANAL',7,NULL,'FECHADO',NULL,NULL,'2026-01-01',NULL,'Domingo fechado',TRUE),
  ('EXCECAO',NULL,'2026-10-12','ABERTO','09:00:00','14:00:00','2026-10-12','2026-10-12','Feriado com horário reduzido',TRUE),
  ('EXCECAO',NULL,'2026-11-20','FECHADO',NULL,NULL,'2026-11-20','2026-11-20','Feriado',TRUE);

INSERT INTO produto (nome,tipo_produto,unidade_medida,sku,descricao,preco_venda,ativo,estoque_minimo) VALUES
  ('Pomada Modeladora Efeito Matte 150g','Revenda','un','POM-MAT-150','Fixação forte',42.90,TRUE,6),
  ('Pomada Brilho Forte 150g','Revenda','un','POM-BRI-150','Alto brilho',39.90,TRUE,6),
  ('Cera Modeladora 100g','Revenda','un','CER-MOD-100','Fixação média',34.90,TRUE,5),
  ('Óleo para Barba 30ml','Revenda','un','OLE-BAR-030','Hidratação',49.90,TRUE,5),
  ('Balm Pós-Barba 80g','Revenda','un','BAL-POS-080','Calmante',44.90,TRUE,4),
  ('Shampoo para Barba 200ml','Revenda','un','SHA-BAR-200','Limpeza',36.90,TRUE,4),
  ('Shampoo Anticaspa 250ml','Revenda','un','SHA-ANT-250','Controle de caspa',32.90,TRUE,4),
  ('Gel Fixador Extra Forte 300g','Revenda','un','GEL-FIX-300','Fixação extra forte',19.90,TRUE,6),
  ('Pente de Madeira','Revenda','un','PEN-MAD-001','Pente antiestático',24.90,TRUE,3),
  ('Pó Texturizador 10g','Ambos','un','PO-TEX-010','Uso e revenda',29.90,TRUE,3),
  ('Lâmina Descartável (cx c/ 100)','Insumo','cx','LAM-DES-100','Lâminas',NULL,TRUE,2),
  ('Álcool 70% 1L','Insumo','l','ALC-070-1L','Desinfecção',NULL,TRUE,5);

INSERT INTO fornecedor (nome_razao_social,documento_fiscal,telefone,email,ativo) VALUES
  ('Distribuidora Fio de Navalha Ltda','10.000.001/0001-00','(11) 4000-0001','vendas@example.com',TRUE),
  ('Cosméticos Barba Forte Comércio','10.000.002/0001-00','(11) 4000-0002','pedidos@example.com',TRUE),
  ('Higiene Pro Suprimentos','10.000.003/0001-00','(11) 4000-0003','contato@example.com',TRUE);

-- Compras começam em rascunho; a atualização para Recebida gera as entradas de estoque.
INSERT INTO compra (id_fornecedor,id_usuario,data_pedido,status,observacao) VALUES
  (1,1,'2026-08-25 10:00:00','Rascunho','Estoque inicial'),
  (2,1,'2026-08-25 10:30:00','Rascunho','Estoque inicial de barba'),
  (3,1,'2026-08-26 09:00:00','Rascunho','Insumos de higiene');
INSERT INTO item_compra (id_compra,id_produto,quantidade,custo_unitario) VALUES
  (1,1,30,24.00),(1,2,30,22.00),(1,3,30,19.00),(1,8,30,10.50),(1,9,30,12.00),(1,10,30,16.00),
  (2,4,30,28.00),(2,5,30,25.00),(2,6,30,20.00),(2,7,30,18.00),
  (3,11,10,85.00),(3,12,20,14.00);
UPDATE compra c
SET valor_total=(SELECT SUM(i.quantidade*i.custo_unitario) FROM item_compra i WHERE i.id_compra=c.id_compra)
WHERE c.id_compra > 0;
UPDATE compra SET status='Recebida',data_recebimento='2026-08-27 14:00:00' WHERE id_compra=1;
UPDATE compra SET status='Recebida',data_recebimento='2026-08-28 11:00:00' WHERE id_compra=2;
UPDATE compra SET status='Recebida',data_recebimento='2026-08-29 10:00:00' WHERE id_compra=3;

DELIMITER $$
CREATE PROCEDURE popular_agendamentos()
BEGIN
  DECLARE d DATE DEFAULT '2026-09-01';
  DECLARE slot INT;
  DECLARE seq INT DEFAULT 0;
  DECLARE prof INT;
  DECLARE cliente_id INT;
  DECLARE agenda_id INT;
  DECLARE pagamento_id INT;
  DECLARE hora_i TIME;
  DECLARE estado VARCHAR(30);
  DECLARE v_serv INT;
  DECLARE v_preco DECIMAL(10,2);
  DECLARE v_dur INT;
  DECLARE v_extra INT;
  DECLARE v_preco_extra DECIMAL(10,2);
  DECLARE v_dur_extra INT;
  DECLARE v_total DECIMAL(10,2);
  DECLARE v_forma VARCHAR(20);
  WHILE d <= '2026-11-07' DO
    IF DAYOFWEEK(d) BETWEEN 3 AND 7 THEN
      SET slot = 0;
      -- Cinco horários para cada um dos dois profissionais ativos: 500 reservas
      -- em 50 dias de funcionamento (cerca de 50 por semana).
      WHILE slot < 10 DO
        SET seq = seq + 1;
        SET prof = IF(slot < 5,1,3);
        SET cliente_id = 1 + MOD(DATEDIFF(d,'2026-09-01')*10+slot,32);
        SET hora_i = MAKETIME(8 + MOD(slot,5)*2,0,0);

        -- Serviço principal: corte social é o mais comum, seguido de degradê e combo.
        SET v_serv = CASE WHEN MOD(seq,23)=0 THEN 6
                          ELSE CASE MOD(seq + DAYOFYEAR(d),10)
                                 WHEN 4 THEN 2 WHEN 5 THEN 2
                                 WHEN 6 THEN 3
                                 WHEN 7 THEN 4 WHEN 8 THEN 4
                                 WHEN 9 THEN 5
                                 ELSE 1 END END;
        SELECT preco, duracao INTO v_preco, v_dur FROM servico WHERE id_servico = v_serv;

        -- Cerca de um em cada seis agendamentos inclui um adicional.
        SET v_extra = IF(MOD(seq,6)=0, 1 + MOD(seq DIV 6,3), NULL);
        SET v_preco_extra = 0;
        SET v_dur_extra = 0;
        IF v_extra IS NOT NULL THEN
          SELECT preco, duracao INTO v_preco_extra, v_dur_extra FROM servico_extra WHERE id_extra = v_extra;
        END IF;
        SET v_total = v_preco + v_preco_extra;
        SET v_forma = CASE MOD(seq,10) WHEN 0 THEN 'Credito' WHEN 1 THEN 'Credito'
                                       WHEN 2 THEN 'Debito' WHEN 3 THEN 'Dinheiro'
                                       ELSE 'Pix' END;

        INSERT INTO agendamento
          (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,criado_em,expira_em)
        VALUES (cliente_id,prof,DAYOFWEEK(d)-1,d,hora_i,ADDTIME(hora_i,SEC_TO_TIME((v_dur+v_dur_extra)*60)),'Aguardando_pagamento','v1.0',
                TIMESTAMP(d,'08:00:00'),TIMESTAMP(d,'08:00:00'),TIMESTAMP(d,'08:10:00'));
        SET agenda_id = LAST_INSERT_ID();
        INSERT INTO agendamento_servico (id_agendamento,id_servico,preco_contratado,duracao_contratada)
        VALUES (agenda_id,v_serv,v_preco,v_dur);
        IF v_extra IS NOT NULL THEN
          INSERT INTO agendamento_extra (id_agendamento,id_extra,preco_contratado,duracao_contratada)
          VALUES (agenda_id,v_extra,v_preco_extra,v_dur_extra);
        END IF;

        SET estado = CASE WHEN MOD(seq,13)=0 AND MOD(seq,2)=1 THEN 'Expirado'
                          WHEN MOD(seq,13)=0 THEN 'Cancelado'
                          WHEN MOD(seq,11)=0 THEN 'Faltou'
                          ELSE 'Concluido' END;
        IF estado = 'Expirado' THEN
          -- Pagamento recusado: a reserva expira e o horário é liberado (RN18).
          INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em)
          VALUES (agenda_id,'Cobranca','Pix',v_total,'Falhou',TIMESTAMP(d,'08:02:00'));
          UPDATE agendamento SET status='Cancelado',cancelado_em=TIMESTAMP(d,'08:10:00'),
                 motivo_cancelamento='Reserva expirada sem pagamento' WHERE id_agendamento=agenda_id;
        ELSE
          INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em,confirmado_em,referencia_provedor,chave_idempotencia)
          VALUES (agenda_id,'Cobranca',v_forma,v_total,'Pago',TIMESTAMP(d,'08:02:00'),TIMESTAMP(d,'08:03:00'),
                  CONCAT('PAG-',agenda_id),CONCAT('idem-',agenda_id));
          SET pagamento_id=LAST_INSERT_ID();
          INSERT INTO movimento_caixa (id_usuario,id_pagamento,tipo,forma_pagamento,valor,data_hora)
          VALUES (2,pagamento_id,'Entrada',v_forma,v_total,TIMESTAMP(d,'08:03:00'));
          UPDATE agendamento SET status='Confirmado',confirmado_em=TIMESTAMP(d,'08:03:00') WHERE id_agendamento=agenda_id;
          IF estado = 'Cancelado' THEN
            -- Cliente cancelou com antecedência: o pagamento original fica e o estorno é um novo lançamento (RN12).
            UPDATE agendamento SET status='Cancelado',cancelado_em=TIMESTAMP(d,'08:30:00'),
                   motivo_cancelamento='Cancelado pelo cliente com antecedência' WHERE id_agendamento=agenda_id;
            INSERT INTO pagamento (id_agendamento,id_pagamento_origem,tipo_operacao,forma_pagamento,valor,status,criado_em,confirmado_em,referencia_provedor,chave_idempotencia)
            VALUES (agenda_id,pagamento_id,'Estorno',v_forma,v_total,'Pago',TIMESTAMP(d,'08:31:00'),TIMESTAMP(d,'08:32:00'),
                    CONCAT('EST-',agenda_id),CONCAT('idem-est-',agenda_id));
            INSERT INTO movimento_caixa (id_usuario,id_pagamento,tipo,forma_pagamento,valor,data_hora,motivo)
            VALUES (2,LAST_INSERT_ID(),'Estorno',v_forma,v_total,TIMESTAMP(d,'08:32:00'),'Estorno de agendamento cancelado');
          ELSEIF estado = 'Concluido' THEN
            UPDATE agendamento SET status='Concluido',checkin_em=TIMESTAMP(d,hora_i) WHERE id_agendamento=agenda_id;
            IF MOD(seq,3)=0 THEN
              INSERT INTO avaliacao (id_agendamento,nota,comentario,data_avaliacao)
              VALUES (agenda_id,
                      CASE MOD(seq,7) WHEN 0 THEN 3 WHEN 1 THEN 4 WHEN 2 THEN 4 ELSE 5 END,
                      CASE MOD(seq,7) WHEN 0 THEN 'Atendimento atrasou um pouco.'
                                      WHEN 1 THEN 'Bom corte.' WHEN 2 THEN 'Gostei, volto sim.'
                                      ELSE 'Ótimo atendimento, recomendo!' END,
                      TIMESTAMP(d,ADDTIME(hora_i,'01:30:00')));
            END IF;
          ELSE
            UPDATE agendamento SET status='Faltou' WHERE id_agendamento=agenda_id;
          END IF;
        END IF;
        SET slot=slot+1;
      END WHILE;
    END IF;
    SET d=DATE_ADD(d,INTERVAL 1 DAY);
  END WHILE;
END$$
DELIMITER ;
CALL popular_agendamentos();
DROP PROCEDURE popular_agendamentos;

DELIMITER $$
CREATE PROCEDURE popular_vendas()
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE venda_id INT;
  DECLARE data_venda DATETIME;
  DECLARE v_prod INT;
  DECLARE v_qtd INT;
  DECLARE v_preco DECIMAL(10,2);
  DECLARE v_desc DECIMAL(10,2);
  DECLARE v_forma VARCHAR(20);
  WHILE i <= 30 DO
    SET data_venda=DATE_ADD('2026-09-02 10:00:00',INTERVAL i*2 DAY);
    -- A pomada matte é o item mais vendido e termina abaixo do estoque mínimo;
    -- as demais vendas se distribuem entre os outros produtos de revenda.
    SET v_prod = IF(MOD(i,2)=0, 1, 2 + MOD(i,9));
    SET v_qtd  = IF(MOD(i,2)=0, 2, 1);
    SELECT preco_venda INTO v_preco FROM produto WHERE id_produto = v_prod;
    SET v_desc = IF(MOD(i,7)=0, 5.00, NULL);
    SET v_forma = CASE MOD(i,4) WHEN 0 THEN 'Dinheiro' WHEN 1 THEN 'Pix' WHEN 2 THEN 'Debito' ELSE 'Credito' END;
    INSERT INTO venda (id_usuario,id_cliente,data_hora,status,valor_total,forma_pagamento)
    VALUES (2,IF(MOD(i,5)=0,NULL,1+MOD(i,32)),data_venda,'Aberta',0,NULL);
    SET venda_id=LAST_INSERT_ID();
    INSERT INTO item_venda (id_venda,id_produto,quantidade,preco_unitario,desconto_unitario)
    VALUES (venda_id,v_prod,v_qtd,v_preco,v_desc);
    UPDATE venda SET status='Concluida',valor_total=v_qtd*(v_preco-COALESCE(v_desc,0)),forma_pagamento=v_forma WHERE id_venda=venda_id;
    INSERT INTO movimento_caixa (id_usuario,id_venda,tipo,forma_pagamento,valor,data_hora)
    VALUES (2,venda_id,'Entrada',v_forma,v_qtd*(v_preco-COALESCE(v_desc,0)),data_venda);
    SET i=i+1;
  END WHILE;
END$$
DELIMITER ;
CALL popular_vendas();
DROP PROCEDURE popular_vendas;

INSERT INTO venda (id_usuario,id_cliente,data_hora,status,valor_total,forma_pagamento)
VALUES (2,7,'2026-11-02 18:40:00','Aberta',49.90,NULL);
SET @venda_aberta=LAST_INSERT_ID();
INSERT INTO item_venda (id_venda,id_produto,quantidade,preco_unitario,desconto_unitario)
VALUES (@venda_aberta,4,1,49.90,NULL);

INSERT INTO registro_higienizacao (id_usuario,data_hora,item_area,etapa,metodo,produto_lote,resultado,observacao)
VALUES (4,'2026-10-30 18:30:00','Máquinas de corte e navalhas','Desinfeccao','Pulverização de álcool 70%','ALC70-L2610','Concluido',NULL);
SET @higi=LAST_INSERT_ID();
INSERT INTO movimento_estoque
  (id_produto,id_usuario,id_registro_higienizacao,tipo,direcao_ajuste,quantidade,custo_unitario,data_hora,motivo)
VALUES (12,4,@higi,'Saida',NULL,0.250,NULL,'2026-10-30 18:40:00',NULL);
INSERT INTO movimento_estoque
  (id_produto,id_usuario,tipo,direcao_ajuste,quantidade,custo_unitario,data_hora,motivo)
VALUES (4,1,'Ajuste','Saida',1,NULL,'2026-10-20 17:00:00','Frasco avariado no transporte');

INSERT INTO conta_pagar (id_fornecedor,id_compra,id_usuario,descricao,categoria,valor,data_vencimento,status)
VALUES (1,1,1,'Compra #1 - Distribuidora','Fornecedor',2587.00,'2026-09-05','Aberta'),
       (NULL,NULL,1,'Aluguel - setembro/2026','Aluguel',2400.00,'2026-09-05','Aberta'),
       (NULL,NULL,2,'Material de limpeza','Limpeza',45.90,'2026-09-17','Aberta');
UPDATE conta_pagar SET status='Paga',data_baixa='2026-09-04 09:00:00',forma_baixa='Pix' WHERE id_conta=1;
UPDATE conta_pagar SET status='Paga',data_baixa='2026-09-04 09:10:00',forma_baixa='Pix' WHERE id_conta=2;
UPDATE conta_pagar SET status='Paga',data_baixa='2026-09-17 11:00:00',forma_baixa='Dinheiro' WHERE id_conta=3;
-- Contas de outubro e novembro: uma paga, uma atrasada e uma ainda a vencer (cenários do G09).
INSERT INTO conta_pagar (id_fornecedor,id_compra,id_usuario,descricao,categoria,valor,data_vencimento,status)
VALUES (NULL,NULL,1,'Aluguel - outubro/2026','Aluguel',2400.00,'2026-10-05','Aberta'),
       (NULL,NULL,1,'Aluguel - novembro/2026','Aluguel',2400.00,'2026-11-05','Atrasada'),
       (NULL,NULL,1,'Energia elétrica - novembro/2026','Energia',318.40,'2026-11-20','Aberta');
UPDATE conta_pagar SET status='Paga',data_baixa='2026-10-05 09:00:00',forma_baixa='Pix' WHERE id_conta=4;

-- O fechamento é ligado enquanto está aberto; depois é encerrado e um novo caixa é aberto.
INSERT INTO fechamento_caixa (id_usuario,aberto_em,saldo_abertura,status) VALUES (1,'2026-09-01 08:00:00',200.00,'Aberto');
SET @fechamento=LAST_INSERT_ID();
UPDATE movimento_caixa SET id_fechamento=@fechamento
WHERE id_movimento > 0 AND data_hora < '2026-11-01 00:00:00';
-- Na contagem do dinheiro faltaram R$ 12,50 (troco); as demais formas conferem com o extrato.
INSERT INTO fechamento_forma (id_fechamento,forma_pagamento,valor_esperado,valor_conferido)
SELECT @fechamento,forma_pagamento,SUM(CASE WHEN tipo='Entrada' THEN valor WHEN tipo IN ('Saida','Estorno') THEN -valor ELSE 0 END),
       SUM(CASE WHEN tipo='Entrada' THEN valor WHEN tipo IN ('Saida','Estorno') THEN -valor ELSE 0 END)
       - IF(forma_pagamento='Dinheiro',12.50,0)
FROM movimento_caixa WHERE id_fechamento=@fechamento GROUP BY forma_pagamento;
UPDATE fechamento_caixa SET status='Fechado',fechado_em='2026-10-31 19:30:00' WHERE id_fechamento=@fechamento;
INSERT INTO fechamento_caixa (id_usuario,aberto_em,saldo_abertura,status) VALUES (2,'2026-11-02 08:00:00',200.00,'Aberto');

INSERT INTO documento_fiscal (id_agendamento,tipo,numero,serie,emitido_em,status,localizador_arquivo)
SELECT id_agendamento,'NFS-e',LPAD(id_agendamento,6,'0'),'A1',TIMESTAMP(data,hora_fim),'Autorizado',CONCAT('nfse/ag-',id_agendamento,'.pdf')
FROM agendamento WHERE status='Concluido' AND MOD(id_agendamento,10)=0;
INSERT INTO documento_fiscal (id_venda,tipo,numero,serie,chave_acesso,emitido_em,status,localizador_arquivo)
SELECT id_venda,'NFC-e',LPAD(id_venda,6,'0'),'1',CONCAT('352610',LPAD(id_venda,38,'0')),data_hora,'Autorizado',CONCAT('nfce/venda-',id_venda,'.xml')
FROM venda WHERE status='Concluida' AND MOD(id_venda,5)=0;

INSERT INTO log_auditoria
  (id_usuario,data_hora,acao,componente,recurso,resultado,identificador_registro,origem,id_correlacao,data_expurgo_prevista)
VALUES
  (2,'2026-09-01 07:55:00','LOGIN','APLICACAO','sessao','SUCESSO',NULL,'app-web','sess-20260901','2031-08-31'),
  (1,'2026-10-10 08:00:00','DML','APLICACAO','usuario_sistema','SUCESSO','5','app-web','usr-5','2031-10-09'),
  (1,'2026-10-31 20:00:00','EXPORTACAO','APLICACAO','fechamento_caixa','SUCESSO',CAST(@fechamento AS CHAR),'app-web','caixa-1','2031-10-30');

ANALYZE TABLE cliente, agendamento, pagamento, venda, movimento_estoque, movimento_caixa;

-- ============================================================================
-- PARTE 5 — SELECT com JOIN (consultas que cruzam várias tabelas)
-- ============================================================================
-- A massa usa datas fixas (set/2026 a nov/2026). A data de referência abaixo
-- deixa os resultados reproduzíveis, sem depender do dia em que o script roda.
SET @data_referencia = '2026-11-11';

-- V01 — Quantos registros cada tabela recebeu na carga?
-- Atende: seção 4 do README (volume da massa de dados)
SELECT tabela, linhas FROM (
  SELECT 'agendamento' AS tabela,COUNT(*) AS linhas FROM agendamento UNION ALL
  SELECT 'agendamento_servico',COUNT(*) FROM agendamento_servico UNION ALL
  SELECT 'agendamento_extra',COUNT(*) FROM agendamento_extra UNION ALL
  SELECT 'avaliacao',COUNT(*) FROM avaliacao UNION ALL
  SELECT 'cliente',COUNT(*) FROM cliente UNION ALL
  SELECT 'compra',COUNT(*) FROM compra UNION ALL
  SELECT 'conta_pagar',COUNT(*) FROM conta_pagar UNION ALL
  SELECT 'documento_fiscal',COUNT(*) FROM documento_fiscal UNION ALL
  SELECT 'fechamento_caixa',COUNT(*) FROM fechamento_caixa UNION ALL
  SELECT 'fechamento_forma',COUNT(*) FROM fechamento_forma UNION ALL
  SELECT 'fornecedor',COUNT(*) FROM fornecedor UNION ALL
  SELECT 'item_compra',COUNT(*) FROM item_compra UNION ALL
  SELECT 'item_venda',COUNT(*) FROM item_venda UNION ALL
  SELECT 'log_auditoria',COUNT(*) FROM log_auditoria UNION ALL
  SELECT 'movimento_caixa',COUNT(*) FROM movimento_caixa UNION ALL
  SELECT 'movimento_estoque',COUNT(*) FROM movimento_estoque UNION ALL
  SELECT 'pagamento',COUNT(*) FROM pagamento UNION ALL
  SELECT 'produto',COUNT(*) FROM produto UNION ALL
  SELECT 'profissional',COUNT(*) FROM profissional UNION ALL
  SELECT 'registro_higienizacao',COUNT(*) FROM registro_higienizacao UNION ALL
  SELECT 'regra_calendario',COUNT(*) FROM regra_calendario UNION ALL
  SELECT 'servico',COUNT(*) FROM servico UNION ALL
  SELECT 'servico_extra',COUNT(*) FROM servico_extra UNION ALL
  SELECT 'usuario_sistema',COUNT(*) FROM usuario_sistema UNION ALL
  SELECT 'venda',COUNT(*) FROM venda
) AS volumes ORDER BY tabela;

-- S01 — Qual é o histórico de atendimentos e pagamentos do cliente 1?
-- Atende: P2 (histórico único de atendimentos e pagamentos) — PN04, PN06
SELECT c.nome AS cliente, a.id_agendamento, a.data, a.hora_inicio, p.nome AS profissional,
       s.nome AS servico, ags.preco_contratado, a.status AS status_agendamento,
       pg.forma_pagamento, pg.tipo_operacao, pg.valor AS valor_pago, pg.status AS status_pagamento
FROM cliente c
JOIN agendamento a           ON a.id_cliente = c.id_cliente
JOIN profissional p          ON p.id_profissional = a.id_profissional
JOIN agendamento_servico ags ON ags.id_agendamento = a.id_agendamento
JOIN servico s               ON s.id_servico = ags.id_servico
LEFT JOIN pagamento pg       ON pg.id_agendamento = a.id_agendamento
WHERE c.id_cliente = 1
ORDER BY a.data, a.hora_inicio, pg.criado_em;

-- S02 — Quais produtos foram comprados de cada fornecedor, com quantidade e custo?
-- Atende: P3 (compras e estoque) — PN10
SELECT f.nome_razao_social AS fornecedor, co.id_compra, DATE(co.data_pedido) AS pedido,
       DATE(co.data_recebimento) AS recebimento, co.status, pr.nome AS produto,
       ic.quantidade, ic.custo_unitario, ic.quantidade * ic.custo_unitario AS subtotal
FROM compra co
JOIN fornecedor f   ON f.id_fornecedor = co.id_fornecedor
JOIN item_compra ic ON ic.id_compra = co.id_compra
JOIN produto pr     ON pr.id_produto = ic.id_produto
ORDER BY co.id_compra, pr.nome;

-- ============================================================================
-- PARTE 6 — UPDATE
-- ============================================================================

-- U01 — Atualizar o e-mail de um cliente que pediu correção do cadastro.
-- Atende: RF01 — PN01 (data_atualizacao é preenchida automaticamente)
UPDATE cliente SET email = 'cliente41.novo@example.com' WHERE id_cliente = 41;
SELECT id_cliente, nome, email, data_atualizacao FROM cliente WHERE id_cliente = 41;

-- U02 — Inativar um serviço adicional que saiu do catálogo, sem apagar o histórico.
-- Atende: RN08 — PN02
UPDATE servico_extra SET ativo = FALSE WHERE id_extra = 3;
SELECT id_extra, nome, ativo FROM servico_extra ORDER BY id_extra;

-- U03 — Reajustar em 10% o preço de venda do óleo para barba.
-- Atende: RF08 — PN09 (vendas antigas mantêm o preço praticado em ITEM_VENDA)
UPDATE produto SET preco_venda = ROUND(preco_venda * 1.10, 2) WHERE id_produto = 4;
SELECT id_produto, nome, preco_venda FROM produto WHERE id_produto = 4;

-- ============================================================================
-- PARTE 7 — DELETE
-- ============================================================================
-- Movimentos de caixa/estoque, pagamentos e logs não podem ser apagados
-- (gatilhos, RN12 e RN14). Só cadastros sem histórico são removidos.

-- D01 — Excluir o cadastro de um cliente que nunca agendou nem comprou (pedido do titular).
-- Atende: RN17 (LGPD) — PN14
DELETE FROM cliente
WHERE id_cliente = 45
  AND NOT EXISTS (SELECT 1 FROM agendamento a WHERE a.id_cliente = 45)
  AND NOT EXISTS (SELECT 1 FROM venda v WHERE v.id_cliente = 45);
SELECT COUNT(*) AS cliente_45_restante FROM cliente WHERE id_cliente = 45;

-- D02 — Remover a exceção de calendário de 20/11/2026, lançada por engano e sem agendamentos.
-- Atende: RN04 — PN03
DELETE FROM regra_calendario
WHERE id_regra_calendario = 9
  AND NOT EXISTS (SELECT 1 FROM agendamento a WHERE a.id_regra_calendario = 9);
SELECT id_regra_calendario, tipo_regra, data_especifica, situacao FROM regra_calendario ORDER BY id_regra_calendario;

-- ============================================================================
-- PARTE 8 — Consultas gerenciais (G01…G11)
-- ============================================================================

-- G01 — Qual é a situação dos agendamentos (concluídos, cancelados, faltas)?
-- Atende: P1 (cancelamentos, atrasos e faltas desorganizam a agenda) — PN05, PN08
SELECT status, COUNT(*) AS quantidade,
       ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM agendamento),1) AS percentual
FROM agendamento GROUP BY status ORDER BY quantidade DESC;

-- G02 — Como está a agenda por data e profissional, com serviços, adicionais e valor contratado?
-- Atende: P1 (organização dos horários) — PN02, PN03
SELECT a.id_agendamento,a.data,a.hora_inicio,p.nome AS profissional,c.nome AS cliente,a.status,
       GROUP_CONCAT(DISTINCT s.nome ORDER BY s.nome SEPARATOR ' + ') AS servicos,
       COALESCE(GROUP_CONCAT(DISTINCT e.nome ORDER BY e.nome SEPARATOR ', '),'-') AS adicionais,
       (SELECT SUM(x.preco_contratado) FROM agendamento_servico x WHERE x.id_agendamento=a.id_agendamento)
       +COALESCE((SELECT SUM(ae.preco_contratado)
          FROM agendamento_extra ae WHERE ae.id_agendamento=a.id_agendamento),0) AS total_contratado
FROM agendamento a
JOIN cliente c ON c.id_cliente=a.id_cliente
JOIN profissional p ON p.id_profissional=a.id_profissional
JOIN agendamento_servico ags ON ags.id_agendamento=a.id_agendamento
JOIN servico s ON s.id_servico=ags.id_servico
LEFT JOIN agendamento_extra age ON age.id_agendamento=a.id_agendamento
LEFT JOIN servico_extra e ON e.id_extra=age.id_extra
GROUP BY a.id_agendamento,a.data,a.hora_inicio,p.nome,c.nome,a.status
ORDER BY a.data,a.hora_inicio LIMIT 30;

-- G03 — Quanto cada profissional faturou por serviço e qual a nota média recebida?
-- Atende: P2 (histórico de atendimentos e receita) — PN06, PN13
SELECT p.nome AS profissional,s.nome AS servico,COUNT(DISTINCT a.id_agendamento) AS atendimentos,
       SUM(ags.preco_contratado) AS receita_servicos,ROUND(AVG(av.nota),2) AS nota_media
FROM agendamento a
JOIN profissional p ON p.id_profissional=a.id_profissional
JOIN agendamento_servico ags ON ags.id_agendamento=a.id_agendamento
JOIN servico s ON s.id_servico=ags.id_servico
LEFT JOIN avaliacao av ON av.id_agendamento=a.id_agendamento
WHERE a.status='Concluido'
GROUP BY p.nome,s.nome ORDER BY receita_servicos DESC;

-- G04 — Quais produtos estão abaixo do estoque mínimo hoje?
-- Atende: P3 (controle de estoque) — PN09, PN10
SELECT id_produto,nome,unidade_medida,saldo,estoque_minimo,
       estoque_minimo-saldo AS quantidade_a_repor
FROM vw_saldo_estoque
WHERE estoque_minimo IS NOT NULL AND saldo<estoque_minimo
ORDER BY quantidade_a_repor DESC;

-- G05 — No fechamento de caixa, quanto era esperado, quanto foi conferido e qual a diferença por forma de pagamento?
-- Atende: P3 (controle do caixa) — PN11
SELECT f.id_fechamento,DATE(f.fechado_em) AS fechamento,ff.forma_pagamento,
       ff.valor_esperado,ff.valor_conferido,ff.diferenca
FROM fechamento_caixa f JOIN fechamento_forma ff ON ff.id_fechamento=f.id_fechamento
ORDER BY f.id_fechamento,ff.forma_pagamento;

-- G06 — Quanto entrou líquido por forma de pagamento, descontando estornos?
-- Atende: P2 (histórico de pagamentos) — PN04, PN08
SELECT forma_pagamento,
       SUM(CASE WHEN tipo_operacao='Cobranca' THEN valor ELSE -valor END) AS valor_liquido,
       SUM(tipo_operacao='Cobranca') AS cobrancas,
       SUM(tipo_operacao='Estorno') AS estornos
FROM pagamento WHERE status='Pago'
GROUP BY forma_pagamento ORDER BY valor_liquido DESC;

-- G07 — Quais produtos mais vendem no balcão e quanto cada um faturou?
-- Atende: P3 (venda de produtos e saída de estoque) — PN09
SELECT p.nome AS produto,SUM(iv.quantidade) AS unidades_vendidas,
       SUM(iv.quantidade*(iv.preco_unitario-COALESCE(iv.desconto_unitario,0))) AS receita_balcao
FROM item_venda iv
JOIN venda v ON v.id_venda=iv.id_venda
JOIN produto p ON p.id_produto=iv.id_produto
WHERE v.status='Concluida'
GROUP BY p.id_produto,p.nome ORDER BY receita_balcao DESC;

-- G08 — KPI: qual a taxa mensal de faltas e cancelamentos? (meta: até 10% ao mês)
-- Atende: P1 (faltas e cancelamentos) — PN08 — fórmula: (faltas + cancelados) / agendamentos do mês
SELECT DATE_FORMAT(data,'%Y-%m') AS mes,
       COUNT(*) AS agendamentos,
       SUM(status='Faltou') AS faltas,
       SUM(status='Cancelado') AS cancelados,
       ROUND(100*SUM(status IN ('Faltou','Cancelado'))/COUNT(*),1) AS taxa_perda_pct,
       IF(100*SUM(status IN ('Faltou','Cancelado'))/COUNT(*) <= 10,'Dentro da meta','Acima da meta') AS situacao
FROM agendamento
GROUP BY DATE_FORMAT(data,'%Y-%m') ORDER BY mes;

-- G09 — Quais contas a pagar estão atrasadas ou vencem nos próximos 15 dias?
-- Atende: P3 (contas a pagar) — PN11
SELECT cp.id_conta, cp.descricao, cp.categoria, COALESCE(f.nome_razao_social,'-') AS fornecedor,
       cp.valor, cp.data_vencimento, cp.status,
       DATEDIFF(@data_referencia, cp.data_vencimento) AS dias_em_atraso
FROM conta_pagar cp
LEFT JOIN fornecedor f ON f.id_fornecedor = cp.id_fornecedor
WHERE cp.status IN ('Aberta','Atrasada')
  AND cp.data_vencimento <= @data_referencia + INTERVAL 15 DAY
ORDER BY cp.data_vencimento;

-- G10 — KPI: quantos atendimentos cada profissional conclui por dia trabalhado? (meta: 8 por dia — RN06)
-- Atende: P1 (aproveitamento da agenda) — PN03, PN06 — fórmula: concluídos / dias com atendimento, por mês
SELECT DATE_FORMAT(a.data,'%Y-%m') AS mes, p.nome AS profissional,
       COUNT(*) AS concluidos,
       COUNT(DISTINCT a.data) AS dias_trabalhados,
       ROUND(COUNT(*)/COUNT(DISTINCT a.data),2) AS atendimentos_por_dia,
       ROUND(100*(COUNT(*)/COUNT(DISTINCT a.data))/8,1) AS pct_da_meta
FROM agendamento a
JOIN profissional p ON p.id_profissional = a.id_profissional
WHERE a.status = 'Concluido'
GROUP BY DATE_FORMAT(a.data,'%Y-%m'), p.nome
ORDER BY mes, profissional;

-- G11 — KPI: qual o ticket médio e a receita mensal dos atendimentos concluídos?
-- Atende: P2 (receita de atendimentos) — PN05, PN13 — fórmula: receita de serviços e adicionais / atendimentos concluídos
SELECT DATE_FORMAT(a.data,'%Y-%m') AS mes,
       COUNT(*) AS atendimentos,
       SUM(t.total) AS receita,
       ROUND(SUM(t.total)/COUNT(*),2) AS ticket_medio
FROM agendamento a
JOIN (SELECT id_agendamento, SUM(preco_contratado) AS total
        FROM (SELECT id_agendamento, preco_contratado FROM agendamento_servico
              UNION ALL
              SELECT id_agendamento, preco_contratado FROM agendamento_extra) itens
       GROUP BY id_agendamento) t ON t.id_agendamento = a.id_agendamento
WHERE a.status = 'Concluido'
GROUP BY DATE_FORMAT(a.data,'%Y-%m') ORDER BY mes;

-- ============================================================================
-- PARTE 9 — Consultas de auditoria (A01…A07): o resultado esperado é 0 violações
-- ============================================================================

-- A01 — Algum profissional tem dois agendamentos ativos com horários sobrepostos?
-- Verifica: RN09
SELECT 'A01 - horários sobrepostos' AS auditoria, COUNT(*) AS violacoes
FROM agendamento a
JOIN agendamento b ON a.id_agendamento<b.id_agendamento AND a.id_profissional=b.id_profissional
 AND a.data=b.data AND a.status<>'Cancelado' AND b.status<>'Cancelado'
 AND a.hora_inicio<b.hora_fim AND a.hora_fim>b.hora_inicio;

-- A02 — Existe agendamento confirmado, concluído ou com falta sem pagamento integral?
-- Verifica: RN02 e RN11
SELECT 'A02 - confirmado sem pagamento integral' AS auditoria, COUNT(*) AS violacoes
FROM agendamento a
WHERE a.status IN ('Confirmado','Concluido','Faltou')
  AND COALESCE((SELECT SUM(CASE WHEN p.tipo_operacao='Cobranca' THEN p.valor ELSE -p.valor END)
                FROM pagamento p WHERE p.id_agendamento=a.id_agendamento AND p.status='Pago'),0)
      < (SELECT COALESCE(SUM(preco_contratado),0) FROM agendamento_servico s WHERE s.id_agendamento=a.id_agendamento)
      + (SELECT COALESCE(SUM(preco_contratado),0) FROM agendamento_extra e WHERE e.id_agendamento=a.id_agendamento);

-- A03 — Algum produto ficou com saldo de estoque negativo?
-- Verifica: RN13
SELECT 'A03 - estoque negativo' AS auditoria, COUNT(*) AS violacoes
FROM vw_saldo_estoque WHERE saldo < 0;

-- A04 — Existe mais de um caixa aberto ao mesmo tempo?
-- Verifica: RN14
SELECT 'A04 - caixa aberto duplicado' AS auditoria, GREATEST(COUNT(*)-1,0) AS violacoes
FROM fechamento_caixa WHERE status='Aberto';

-- A05 — Existe agendamento sem nenhum serviço principal registrado?
-- Verifica: RN05 (preço e duração ficam no item do agendamento) e RN01
SELECT 'A05 - agendamento sem serviço' AS auditoria, COUNT(*) AS violacoes
FROM agendamento a
WHERE NOT EXISTS (SELECT 1 FROM agendamento_servico s WHERE s.id_agendamento=a.id_agendamento);

-- A06 — Existe avaliação de agendamento que não foi concluído?
-- Verifica: RF07 (avaliação só após atendimento concluído)
SELECT 'A06 - avaliação sem atendimento concluído' AS auditoria, COUNT(*) AS violacoes
FROM avaliacao av JOIN agendamento a ON a.id_agendamento=av.id_agendamento
WHERE a.status <> 'Concluido';

-- A07 — Algum estorno devolveu mais do que o pagamento original?
-- Verifica: RN12 (estorno referencia o pagamento original, sem apagá-lo)
SELECT 'A07 - estorno maior que a cobrança' AS auditoria, COUNT(*) AS violacoes
FROM pagamento o
JOIN (SELECT id_pagamento_origem, SUM(valor) AS estornado
        FROM pagamento WHERE tipo_operacao='Estorno' AND status='Pago'
       GROUP BY id_pagamento_origem) e ON e.id_pagamento_origem=o.id_pagamento
WHERE e.estornado > o.valor;

-- ============================================================================
-- PARTE 10 — Testes das regras (T01…T05): cada linha deve mostrar OK
-- ============================================================================
-- O procedimento tenta gravar dados inválidos, captura o erro esperado e é
-- removido no final. Nenhum registro inválido fica no banco.

DROP PROCEDURE IF EXISTS executar_testes_regras;
DELIMITER $$
CREATE PROCEDURE executar_testes_regras()
BEGIN
  DECLARE bloqueado BOOL;
  DECLARE ag INT;
  DECLARE prof INT;
  DECLARE regra INT;
  DECLARE dia DATE;
  DECLARE inicio TIME;

  SELECT id_agendamento,id_profissional,id_regra_calendario,data,hora_inicio
    INTO ag,prof,regra,dia,inicio FROM agendamento WHERE status='Concluido' LIMIT 1;

  -- T01 — Verifica: RN09 (sem sobreposição de horário do mesmo profissional)
  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (1,prof,regra,dia,inicio,ADDTIME(inicio,'00:40:00'),'Aguardando_pagamento','teste',NOW(),DATE_ADD(NOW(),INTERVAL 10 MINUTE));
  END;
  SELECT 'T01 - bloqueia sobreposição de agenda (RN09)' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  -- T02 — Verifica: RN03 (formas de pagamento permitidas)
  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em)
    VALUES (ag,'Cobranca','Fiado',10.00,'Pendente',NOW());
  END;
  SELECT 'T02 - bloqueia forma de pagamento inválida (RN03)' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  -- T03 — Verifica: RF07 (nota da avaliação entre 1 e 5)
  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO avaliacao (id_agendamento,nota,comentario) VALUES (ag,6,'Nota inválida');
  END;
  SELECT 'T03 - bloqueia nota fora de 1 a 5 (RF07)' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  -- T04 — Verifica: RN14 (apenas um caixa aberto)
  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO fechamento_caixa (id_usuario,aberto_em,saldo_abertura,status) VALUES (1,NOW(),0,'Aberto');
  END;
  SELECT 'T04 - bloqueia segundo caixa aberto (RN14)' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  -- T05 — Verifica: RN17 (marketing exige consentimento registrado)
  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO cliente (nome,telefone,ativo,aceita_marketing) VALUES ('Teste marketing','(11) 95550-9999',TRUE,TRUE);
  END;
  SELECT 'T05 - bloqueia marketing sem consentimento (RN17)' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;
END$$
DELIMITER ;

CALL executar_testes_regras();
DROP PROCEDURE executar_testes_regras;

-- Fim do script.
