/*
  Barbearia The Family Hair — massa de dados fictícia para MySQL 8.0.16+
  Execute depois de docs/script.sql, em um banco recém-criado.
  O script respeita os gatilhos do script.sql: compras e
  vendas são concluídas pelas transições normais, sem inserir movimentos
  de estoque que já são criados automaticamente pelos gatilhos.
*/

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
  DECLARE prof INT;
  DECLARE cliente_id INT;
  DECLARE agenda_id INT;
  DECLARE pagamento_id INT;
  DECLARE hora_i TIME;
  DECLARE estado VARCHAR(30);
  WHILE d <= '2026-11-07' DO
    IF DAYOFWEEK(d) BETWEEN 3 AND 7 THEN
      SET slot = 0;
      -- Cinco horários para cada um dos dois profissionais ativos: cerca de
      -- 490 reservas no período, próximo ao volume da massa original.
      WHILE slot < 10 DO
        SET prof = IF(slot < 5,1,3);
        SET cliente_id = 1 + MOD(DATEDIFF(d,'2026-09-01')*10+slot,32);
        SET hora_i = MAKETIME(8 + MOD(slot,5)*2,0,0);
        INSERT INTO agendamento
          (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,criado_em,expira_em)
        VALUES (cliente_id,prof,DAYOFWEEK(d)-1,d,hora_i,ADDTIME(hora_i,'00:40:00'),'Aguardando_pagamento','v1.0',
                TIMESTAMP(d,'08:00:00'),TIMESTAMP(d,'08:00:00'),TIMESTAMP(d,'08:10:00'));
        SET agenda_id = LAST_INSERT_ID();
        INSERT INTO agendamento_servico (id_agendamento,id_servico,preco_contratado,duracao_contratada)
        VALUES (agenda_id,1,50.00,40);
        SET estado = CASE WHEN MOD(agenda_id,13)=0 THEN 'Cancelado'
                           WHEN MOD(agenda_id,11)=0 THEN 'Faltou'
                           ELSE 'Concluido' END;
        IF estado = 'Cancelado' THEN
          INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em)
          VALUES (agenda_id,'Cobranca','Pix',50.00,'Falhou',TIMESTAMP(d,'08:02:00'));
          UPDATE agendamento SET status='Cancelado',cancelado_em=TIMESTAMP(d,'08:10:00'),motivo_cancelamento='Cancelamento fictício' WHERE id_agendamento=agenda_id;
        ELSE
          INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em,confirmado_em,referencia_provedor,chave_idempotencia)
          VALUES (agenda_id,'Cobranca',IF(MOD(agenda_id,4)=0,'Credito','Pix'),50.00,'Pago',TIMESTAMP(d,'08:02:00'),TIMESTAMP(d,'08:03:00'),
                  CONCAT('PAG-',agenda_id),CONCAT('idem-',agenda_id));
          SET pagamento_id=LAST_INSERT_ID();
          INSERT INTO movimento_caixa (id_usuario,id_pagamento,tipo,forma_pagamento,valor,data_hora)
          VALUES (2,pagamento_id,'Entrada',IF(MOD(agenda_id,4)=0,'Credito','Pix'),50.00,TIMESTAMP(d,'08:03:00'));
          UPDATE agendamento SET status='Confirmado',confirmado_em=TIMESTAMP(d,'08:03:00') WHERE id_agendamento=agenda_id;
          IF estado='Concluido' THEN
            UPDATE agendamento SET status='Concluido',checkin_em=TIMESTAMP(d,hora_i) WHERE id_agendamento=agenda_id;
            IF MOD(agenda_id,3)=0 THEN
              INSERT INTO avaliacao (id_agendamento,nota,comentario,data_avaliacao)
              VALUES (agenda_id,5,'Ótimo atendimento, recomendo!',TIMESTAMP(d,ADDTIME(hora_i,'01:00:00')));
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
  WHILE i <= 30 DO
    SET data_venda=DATE_ADD('2026-09-02 10:00:00',INTERVAL i*2 DAY);
    INSERT INTO venda (id_usuario,id_cliente,data_hora,status,valor_total,forma_pagamento)
    VALUES (2,1+MOD(i,32),data_venda,'Aberta',0,NULL);
    SET venda_id=LAST_INSERT_ID();
    INSERT INTO item_venda (id_venda,id_produto,quantidade,preco_unitario,desconto_unitario)
    VALUES (venda_id,1,1,42.90,NULL);
    UPDATE venda SET status='Concluida',valor_total=42.90,forma_pagamento=IF(MOD(i,3)=0,'Dinheiro','Pix') WHERE id_venda=venda_id;
    INSERT INTO movimento_caixa (id_usuario,id_venda,tipo,forma_pagamento,valor,data_hora)
    VALUES (2,venda_id,'Entrada',IF(MOD(i,3)=0,'Dinheiro','Pix'),42.90,data_venda);
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

-- O fechamento é ligado enquanto está aberto; depois é encerrado e um novo caixa é aberto.
INSERT INTO fechamento_caixa (id_usuario,aberto_em,saldo_abertura,status) VALUES (1,'2026-09-01 08:00:00',200.00,'Aberto');
SET @fechamento=LAST_INSERT_ID();
UPDATE movimento_caixa SET id_fechamento=@fechamento
WHERE id_movimento > 0 AND data_hora < '2026-11-01 00:00:00';
INSERT INTO fechamento_forma (id_fechamento,forma_pagamento,valor_esperado,valor_conferido)
SELECT @fechamento,forma_pagamento,SUM(CASE WHEN tipo='Entrada' THEN valor WHEN tipo IN ('Saida','Estorno') THEN -valor ELSE 0 END),
       SUM(CASE WHEN tipo='Entrada' THEN valor WHEN tipo IN ('Saida','Estorno') THEN -valor ELSE 0 END)
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
