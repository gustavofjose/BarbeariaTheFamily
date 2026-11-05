/*
  Barbearia The Family Hair — testes e consultas para MySQL 8.0.16+
  Execute depois de docs/script.sql e docs/massa-de-dados.sql.
  As consultas são somente leitura; os testes de regras capturam os erros
  esperados em um procedimento e não deixam registros inválidos no banco.
*/

USE `barbearia_the_family`;

/* 1. Volume por tabela */
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

/* G01. Situação dos agendamentos: acompanha confirmações, cancelamentos e faltas. */
SELECT status,COUNT(*) AS quantidade,
       ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM agendamento),1) AS percentual
FROM agendamento GROUP BY status ORDER BY quantidade DESC;

/* G02. Agenda com serviços, adicionais e valor contratado. */
SELECT a.id_agendamento,a.data,a.hora_inicio,p.nome AS profissional,c.nome AS cliente,a.status,
       GROUP_CONCAT(DISTINCT s.nome ORDER BY s.nome SEPARATOR ' + ') AS servicos,
       COALESCE(GROUP_CONCAT(DISTINCT e.nome ORDER BY e.nome SEPARATOR ', '),'-') AS adicionais,
       SUM(DISTINCT ags.preco_contratado)+COALESCE((SELECT SUM(ae.preco_contratado)
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

/* G03. Receita por profissional e serviço. */
SELECT p.nome AS profissional,s.nome AS servico,COUNT(DISTINCT a.id_agendamento) AS atendimentos,
       SUM(ags.preco_contratado) AS receita_servicos,ROUND(AVG(av.nota),2) AS nota_media
FROM agendamento a
JOIN profissional p ON p.id_profissional=a.id_profissional
JOIN agendamento_servico ags ON ags.id_agendamento=a.id_agendamento
JOIN servico s ON s.id_servico=ags.id_servico
LEFT JOIN avaliacao av ON av.id_agendamento=a.id_agendamento
WHERE a.status='Concluido'
GROUP BY p.nome,s.nome ORDER BY receita_servicos DESC;

/* 5. Pagamentos e estornos por forma */
SELECT forma_pagamento,
       SUM(CASE WHEN tipo_operacao='Cobranca' THEN valor ELSE -valor END) AS liquido,
       SUM(tipo_operacao='Cobranca') AS cobrancas,SUM(tipo_operacao='Estorno') AS estornos
FROM pagamento WHERE status='Pago' GROUP BY forma_pagamento;

/* 6. Produtos vendidos e receita de balcão */
SELECT p.nome,SUM(iv.quantidade) AS unidades,
       SUM(iv.quantidade*(iv.preco_unitario-COALESCE(iv.desconto_unitario,0))) AS receita
FROM item_venda iv JOIN venda v ON v.id_venda=iv.id_venda
JOIN produto p ON p.id_produto=iv.id_produto
WHERE v.status='Concluida' GROUP BY p.id_produto,p.nome ORDER BY receita DESC;

/* G04. Saldo atual e alerta de estoque mínimo. */
SELECT * FROM vw_saldo_estoque ORDER BY saldo;
SELECT id_produto,nome,saldo,estoque_minimo FROM vw_saldo_estoque
WHERE estoque_minimo IS NOT NULL AND saldo<estoque_minimo;

/* G05. Conciliação por fechamento de caixa. */
SELECT f.id_fechamento,DATE(f.fechado_em) AS fechamento,ff.forma_pagamento,
       ff.valor_esperado,ff.valor_conferido,ff.diferenca
FROM fechamento_caixa f JOIN fechamento_forma ff ON ff.id_fechamento=f.id_fechamento
ORDER BY f.id_fechamento,ff.forma_pagamento;

/* 9. Auditoria das regras: cada consulta deve retornar zero violações. */
SELECT 'A01 - horários sobrepostos' AS regra,COUNT(*) AS violacoes FROM agendamento a
JOIN agendamento b ON a.id_agendamento<b.id_agendamento AND a.id_profissional=b.id_profissional
 AND a.data=b.data AND a.status<>'Cancelado' AND b.status<>'Cancelado'
 AND a.hora_inicio<b.hora_fim AND a.hora_fim>b.hora_inicio
UNION ALL
SELECT 'A02 - confirmado sem pagamento integral',COUNT(*) FROM agendamento a
WHERE a.status IN ('Confirmado','Concluido','Faltou') AND COALESCE((SELECT SUM(CASE WHEN p.tipo_operacao='Cobranca' THEN p.valor ELSE -p.valor END)
 FROM pagamento p WHERE p.id_agendamento=a.id_agendamento AND p.status='Pago'),0) <
 (SELECT COALESCE(SUM(preco_contratado),0) FROM agendamento_servico s WHERE s.id_agendamento=a.id_agendamento)+
 (SELECT COALESCE(SUM(preco_contratado),0) FROM agendamento_extra e WHERE e.id_agendamento=a.id_agendamento)
UNION ALL
SELECT 'A03 - estoque negativo',COUNT(*) FROM (
 SELECT id_produto FROM movimento_estoque GROUP BY id_produto HAVING SUM(CASE
   WHEN tipo='Entrada' OR (tipo='Ajuste' AND direcao_ajuste='Entrada') THEN quantidade
   ELSE -quantidade END)<0
) AS negativos
UNION ALL
SELECT 'A04 - caixa aberto duplicado',GREATEST(COUNT(*)-1,0) FROM fechamento_caixa WHERE status='Aberto';

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

  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (1,prof,regra,dia,inicio,ADDTIME(inicio,'00:40:00'),'Aguardando_pagamento','teste',NOW(),DATE_ADD(NOW(),INTERVAL 10 MINUTE));
  END;
  SELECT 'T01 - bloqueia sobreposição de agenda' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,criado_em)
    VALUES (ag,'Cobranca','Fiado',10.00,'Pendente',NOW());
  END;
  SELECT 'T02 - bloqueia forma de pagamento inválida' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO avaliacao (id_agendamento,nota,comentario) VALUES (ag,6,'Nota inválida');
  END;
  SELECT 'T03 - bloqueia nota fora de 1 a 5' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO fechamento_caixa (id_usuario,aberto_em,saldo_abertura,status) VALUES (1,NOW(),0,'Aberto');
  END;
  SELECT 'T04 - bloqueia segundo caixa aberto' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;

  SET bloqueado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET bloqueado=TRUE;
    INSERT INTO cliente (nome,telefone,ativo,aceita_marketing) VALUES ('Teste marketing','(11) 95550-9999',TRUE,TRUE);
  END;
  SELECT 'T05 - bloqueia marketing sem consentimento' AS teste,IF(bloqueado,'OK','FALHOU') AS resultado;
END$$
DELIMITER ;

CALL executar_testes_regras();
DROP PROCEDURE executar_testes_regras;
