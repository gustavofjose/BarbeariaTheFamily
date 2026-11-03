/* =============================================================================
   Barbearia The Family Hair — TESTES E CONSULTAS
   Rode DEPOIS de 01 (estrutura = docs/script.sql) e 02_popular_banco.sql.
   Este arquivo NÃO altera os dados (os testes de regra e as demos de UPDATE/DELETE
   são desfeitos automaticamente). Pode rodar quantas vezes quiser.
   Data de referência fixa: 02/11/2026 (para o resultado ser sempre o mesmo).
   ============================================================================= */
SET search_path TO barbearia, public;

/* =============================================================================
   PARTE 1 — VOLUME POR TABELA (a "explicação do volume" pedida no README)
   ============================================================================= */
SELECT tabela, linhas FROM (
  SELECT 'agendamento' tabela, count(*) linhas FROM agendamento UNION ALL
  SELECT 'agendamento_servico', count(*) FROM agendamento_servico UNION ALL
  SELECT 'agendamento_extra', count(*) FROM agendamento_extra UNION ALL
  SELECT 'avaliacao', count(*) FROM avaliacao UNION ALL
  SELECT 'cliente', count(*) FROM cliente UNION ALL
  SELECT 'compra', count(*) FROM compra UNION ALL
  SELECT 'conta_pagar', count(*) FROM conta_pagar UNION ALL
  SELECT 'documento_fiscal', count(*) FROM documento_fiscal UNION ALL
  SELECT 'fechamento_caixa', count(*) FROM fechamento_caixa UNION ALL
  SELECT 'fechamento_forma', count(*) FROM fechamento_forma UNION ALL
  SELECT 'fornecedor', count(*) FROM fornecedor UNION ALL
  SELECT 'item_compra', count(*) FROM item_compra UNION ALL
  SELECT 'item_venda', count(*) FROM item_venda UNION ALL
  SELECT 'log_auditoria', count(*) FROM log_auditoria UNION ALL
  SELECT 'movimento_caixa', count(*) FROM movimento_caixa UNION ALL
  SELECT 'movimento_estoque', count(*) FROM movimento_estoque UNION ALL
  SELECT 'pagamento', count(*) FROM pagamento UNION ALL
  SELECT 'produto', count(*) FROM produto UNION ALL
  SELECT 'profissional', count(*) FROM profissional UNION ALL
  SELECT 'registro_higienizacao', count(*) FROM registro_higienizacao UNION ALL
  SELECT 'regra_calendario', count(*) FROM regra_calendario UNION ALL
  SELECT 'servico', count(*) FROM servico UNION ALL
  SELECT 'servico_extra', count(*) FROM servico_extra UNION ALL
  SELECT 'usuario_sistema', count(*) FROM usuario_sistema UNION ALL
  SELECT 'venda', count(*) FROM venda) x
ORDER BY tabela;

-- Distribuição dos agendamentos por status (cenários exigidos: concluídos, cancelados, faltas...)
SELECT status, count(*) AS qtd, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
  FROM agendamento GROUP BY status ORDER BY qtd DESC;

/* =============================================================================
   PARTE 2 — CONSULTAS COM JOIN (pergunta que cada uma responde)
   ============================================================================= */

-- J1. Qual é a agenda da próxima semana (03 a 07/11), com cliente, barbeiro, serviços e total?
SELECT a.data, a.hora_inicio, a.hora_fim, pr.nome AS profissional, c.nome AS cliente, a.status,
       string_agg(DISTINCT s.nome, ' + ') AS servicos,
       COALESCE(string_agg(DISTINCT e.nome, ', '), '-') AS adicionais,
       (SELECT sum(x.preco_contratado) FROM agendamento_servico x WHERE x.id_agendamento = a.id_agendamento)
                       + COALESCE((SELECT sum(y.preco_contratado) FROM agendamento_extra y WHERE y.id_agendamento = a.id_agendamento), 0) AS total
  FROM agendamento a
  JOIN cliente c       ON c.id_cliente = a.id_cliente
  JOIN profissional pr ON pr.id_profissional = a.id_profissional
  JOIN agendamento_servico ags ON ags.id_agendamento = a.id_agendamento
  JOIN servico s       ON s.id_servico = ags.id_servico
  LEFT JOIN agendamento_extra ae ON ae.id_agendamento = a.id_agendamento
  LEFT JOIN servico_extra e      ON e.id_extra = ae.id_extra
 WHERE a.data BETWEEN date '2026-11-03' AND date '2026-11-07'
 GROUP BY a.id_agendamento, a.data, a.hora_inicio, a.hora_fim, pr.nome, c.nome, a.status
 ORDER BY a.data, a.hora_inicio, pr.nome;

-- J2. Quanto cada barbeiro faturou em serviços concluídos (set–out/2026) e qual a nota média?
SELECT pr.nome AS profissional,
       count(DISTINCT a.id_agendamento)                                   AS atendimentos,
       sum(ags.preco_contratado)                                          AS receita_servicos,
       round(avg(av.nota), 2)                                             AS nota_media
  FROM agendamento a
  JOIN profissional pr ON pr.id_profissional = a.id_profissional
  JOIN agendamento_servico ags ON ags.id_agendamento = a.id_agendamento
  LEFT JOIN avaliacao av ON av.id_agendamento = a.id_agendamento
 WHERE a.status = 'Concluido'
 GROUP BY pr.nome ORDER BY receita_servicos DESC;

-- J3. Quais serviços mais saem e quanto rendem? (RN05: usa o preço gravado no agendamento)
SELECT s.nome, count(*) AS vezes, sum(ags.preco_contratado) AS receita, round(avg(ags.duracao_contratada)) AS duracao_media_min
  FROM agendamento_servico ags
  JOIN servico s ON s.id_servico = ags.id_servico
  JOIN agendamento a ON a.id_agendamento = ags.id_agendamento AND a.status = 'Concluido'
 GROUP BY s.nome ORDER BY receita DESC;

-- J4. Faturamento por forma de pagamento (cobranças pagas menos estornos pagos)
SELECT forma_pagamento,
       sum(CASE WHEN tipo_operacao = 'Cobranca' THEN valor ELSE -valor END) AS liquido,
       count(*) FILTER (WHERE tipo_operacao = 'Cobranca') AS cobrancas,
       count(*) FILTER (WHERE tipo_operacao = 'Estorno')  AS estornos
  FROM pagamento WHERE status = 'Pago' GROUP BY forma_pagamento ORDER BY liquido DESC;

-- J5. Que produtos foram vendidos no balcão, quanto e a que cliente (quando identificado)?
SELECT p.nome, sum(iv.quantidade) AS unidades,
       sum(iv.quantidade * (iv.preco_unitario - COALESCE(iv.desconto_unitario, 0))) AS receita
  FROM item_venda iv
  JOIN venda v   ON v.id_venda = iv.id_venda AND v.status = 'Concluida'
  JOIN produto p ON p.id_produto = iv.id_produto
 GROUP BY p.nome ORDER BY receita DESC;

/* =============================================================================
   PARTE 3 — UPDATE e DELETE demonstrativos (tudo dentro de transação com ROLLBACK)
   ============================================================================= */
BEGIN;
  -- U1. Reajustar o preço do Corte Social (RN05: agendamentos antigos mantêm o preço gravado)
  UPDATE servico SET preco = 55.00 WHERE nome = 'Corte Social';
  SELECT nome, preco FROM servico WHERE nome = 'Corte Social';
  SELECT count(*) AS agendamentos_antigos_com_preco_50
    FROM agendamento_servico ags JOIN servico s USING (id_servico)
   WHERE s.nome = 'Corte Social' AND ags.preco_contratado = 50.00;

  -- U2. Inativar um serviço em vez de excluir (RN08)
  UPDATE servico SET ativo = false WHERE nome = 'Acabamento (Pezinho)';

  -- D1. Excluir um serviço que nunca foi usado (permitido)
  DELETE FROM servico WHERE nome = 'Corte Promoção Inauguração';
  SELECT count(*) AS servicos_restantes FROM servico;
ROLLBACK;   -- desfaz tudo: o banco volta ao estado anterior

/* =============================================================================
   PARTE 4 — CONSULTAS GERENCIAIS G01–G05 (README, seção 1.6)
   ============================================================================= */

-- G01. Ocupação da agenda: minutos reservados ÷ minutos disponíveis, por profissional e semana.
--      Disponível = expediente dos dias abertos (calendário + exceções) entre o 1º e o último atendimento do profissional.
WITH dias_abertos AS (
  SELECT g::date AS dia, EXTRACT(EPOCH FROM (r.hora_fechamento - r.hora_abertura)) / 60 AS min_expediente
    FROM generate_series(date '2026-08-31', date '2026-11-08', interval '1 day') g
    CROSS JOIN LATERAL (
         SELECT * FROM regra_calendario r
          WHERE r.ativo AND r.situacao = 'ABERTO'
            AND ((r.tipo_regra = 'EXCECAO' AND r.data_especifica = g::date)
              OR (r.tipo_regra = 'SEMANAL' AND r.dia_semana = EXTRACT(ISODOW FROM g)::int
                  AND NOT EXISTS (SELECT 1 FROM regra_calendario e WHERE e.tipo_regra = 'EXCECAO' AND e.ativo AND e.data_especifica = g::date)))
          LIMIT 1) r),
janela AS (SELECT id_profissional, min(data) AS ini, max(data) AS fim FROM agendamento GROUP BY 1),
disp AS (
  SELECT j.id_profissional, date_trunc('week', d.dia)::date AS semana, sum(d.min_expediente) AS min_disponiveis
    FROM janela j JOIN dias_abertos d ON d.dia BETWEEN j.ini AND j.fim
   GROUP BY 1, 2),
res AS (
  SELECT a.id_profissional, date_trunc('week', a.data)::date AS semana,
         sum(EXTRACT(EPOCH FROM (a.hora_fim - a.hora_inicio)) / 60) AS min_reservados
    FROM agendamento a WHERE a.status IN ('Confirmado', 'Concluido', 'Faltou')
   GROUP BY 1, 2)
SELECT p.nome AS profissional, disp.semana, res.min_reservados::int, disp.min_disponiveis::int,
       round(100 * res.min_reservados / disp.min_disponiveis, 1) AS ocupacao_pct
  FROM disp JOIN res USING (id_profissional, semana) JOIN profissional p USING (id_profissional)
 ORDER BY disp.semana, p.nome;

-- G02. Cancelamentos e faltas por mês (inclui cancelamentos tardios < 2h — RN07)
SELECT to_char(a.data, 'YYYY-MM') AS mes,
       count(*)                                            AS reservas,
       count(*) FILTER (WHERE a.status = 'Cancelado')      AS cancelados,
       count(*) FILTER (WHERE a.status = 'Cancelado'
             AND a.cancelado_em > (a.data + a.hora_inicio) AT TIME ZONE 'America/Sao_Paulo' - interval '2 hours') AS cancel_tardios,
       count(*) FILTER (WHERE a.status = 'Faltou')         AS faltas,
       round(100.0 * count(*) FILTER (WHERE a.status IN ('Cancelado', 'Faltou')) / count(*), 1) AS pct_perdido
  FROM agendamento a WHERE a.data <= date '2026-11-02'
 GROUP BY 1 ORDER BY 1;

-- G03. Atendimentos concluídos por profissional e dia (últimos 7 dias úteis com movimento antes de 02/11)
SELECT a.data, p.nome AS profissional, count(*) AS atendimentos
  FROM agendamento a JOIN profissional p USING (id_profissional)
 WHERE a.status = 'Concluido' AND a.data BETWEEN date '2026-10-26' AND date '2026-10-31'
 GROUP BY a.data, p.nome ORDER BY a.data, p.nome;

-- G04. Produtos com saldo abaixo do mínimo na data da consulta
SELECT p.nome, p.unidade_medida, s.saldo, p.estoque_minimo, (p.estoque_minimo - s.saldo) AS falta_repor
  FROM produto p
  JOIN (SELECT id_produto, sum(CASE tipo WHEN 'Entrada' THEN quantidade WHEN 'Saida' THEN -quantidade ELSE 0 END) AS saldo
          FROM movimento_estoque GROUP BY id_produto) s USING (id_produto)
 WHERE p.ativo AND s.saldo < p.estoque_minimo
 ORDER BY falta_repor DESC;

-- G05. Conciliação do caixa: conferido − esperado por forma e fechamento (diferenças ≠ 0)
SELECT f.id_fechamento, f.fechado_em::date AS fechamento, ff.forma_pagamento,
       ff.valor_esperado, ff.valor_conferido, ff.diferenca,
       (SELECT string_agg(m.motivo, '; ') FROM movimento_caixa m
         WHERE m.id_fechamento = f.id_fechamento AND m.tipo = 'Ajuste' AND m.forma_pagamento = ff.forma_pagamento) AS ajuste_registrado
  FROM fechamento_forma ff JOIN fechamento_caixa f USING (id_fechamento)
 WHERE ff.diferenca <> 0 ORDER BY f.fechado_em;

-- G06 (extra). Clientes sem agendamento nos últimos 30 dias (campanha de retorno — só quem aceitou marketing)
SELECT c.id_cliente, c.nome, c.telefone, max(a.data) AS ultimo_agendamento
  FROM cliente c LEFT JOIN agendamento a ON a.id_cliente = c.id_cliente AND a.status IN ('Concluido', 'Confirmado')
 WHERE c.ativo AND c.aceita_marketing
 GROUP BY c.id_cliente, c.nome, c.telefone
HAVING max(a.data) IS NULL OR max(a.data) < date '2026-11-02' - 30
 ORDER BY ultimo_agendamento NULLS FIRST;

/* =============================================================================
   PARTE 5 — AUDITORIAS A01–A09: cada uma deve retornar 0 linhas ("0 = tudo certo")
   ============================================================================= */
SELECT codigo, regra, violacoes,
       CASE WHEN violacoes = 0 THEN 'OK' ELSE 'VERIFICAR' END AS resultado
FROM (
  SELECT 'A01' codigo, 'RN09 - sobreposição de horários do mesmo profissional' regra, count(*) violacoes
    FROM agendamento a JOIN agendamento b ON a.id_profissional = b.id_profissional AND a.data = b.data
     AND a.id_agendamento < b.id_agendamento AND a.hora_inicio < b.hora_fim AND b.hora_inicio < a.hora_fim
   WHERE a.status <> 'Cancelado' AND b.status <> 'Cancelado'
  UNION ALL
  SELECT 'A02', 'RN11 - confirmado/concluído/faltou sem pagamento integral confirmado', count(*)
    FROM agendamento a
   WHERE a.status IN ('Confirmado', 'Concluido', 'Faltou')
     AND COALESCE((SELECT sum(CASE tipo_operacao WHEN 'Cobranca' THEN valor ELSE -valor END) FROM pagamento p
                    WHERE p.id_agendamento = a.id_agendamento AND p.status = 'Pago'), 0)
       < (SELECT sum(preco_contratado) FROM agendamento_servico s WHERE s.id_agendamento = a.id_agendamento)
       + COALESCE((SELECT sum(preco_contratado) FROM agendamento_extra e WHERE e.id_agendamento = a.id_agendamento), 0)
  UNION ALL
  SELECT 'A03', 'RN13 - estoque negativo', count(*)
    FROM (SELECT id_produto FROM movimento_estoque GROUP BY id_produto
           HAVING sum(CASE tipo WHEN 'Entrada' THEN quantidade WHEN 'Saida' THEN -quantidade ELSE 0 END) < 0) x
  UNION ALL
  SELECT 'A04', 'RN14 - movimento de caixa dentro de período fechado sem vínculo ao fechamento', count(*)
    FROM movimento_caixa m
   WHERE m.id_fechamento IS NULL
     AND m.data_hora <= (SELECT max(fechado_em) FROM fechamento_caixa WHERE status = 'Fechado')
  UNION ALL
  SELECT 'A05', 'RN04 - agendamento fora do expediente da regra de calendário', count(*)
    FROM agendamento a JOIN regra_calendario r ON r.id_regra_calendario = a.id_regra_calendario
   WHERE r.situacao <> 'ABERTO' OR a.hora_inicio < r.hora_abertura OR a.hora_fim > r.hora_fechamento
      OR (r.tipo_regra = 'SEMANAL' AND EXTRACT(ISODOW FROM a.data)::int <> r.dia_semana)
      OR (r.tipo_regra = 'EXCECAO' AND a.data <> r.data_especifica)
  UNION ALL
  SELECT 'A06', 'RN13 - venda concluída sem saída de estoque do item', count(*)
    FROM item_venda iv JOIN venda v ON v.id_venda = iv.id_venda AND v.status = 'Concluida'
   WHERE NOT EXISTS (SELECT 1 FROM movimento_estoque m WHERE m.id_venda = iv.id_venda AND m.id_produto = iv.id_produto AND m.tipo = 'Saida')
  UNION ALL
  SELECT 'A07', 'Pagamento pago (cobrança/estorno) sem movimento de caixa', count(*)
    FROM pagamento p WHERE p.status = 'Pago' AND NOT EXISTS (SELECT 1 FROM movimento_caixa m WHERE m.id_pagamento = p.id_pagamento)
  UNION ALL
  SELECT 'A08', 'RN12 - estornos acima do valor cobrado', count(*)
    FROM (SELECT id_agendamento FROM pagamento WHERE status = 'Pago' GROUP BY id_agendamento
           HAVING sum(CASE WHEN tipo_operacao = 'Estorno' THEN valor END) > sum(CASE WHEN tipo_operacao = 'Cobranca' THEN valor END)) x
  UNION ALL
  SELECT 'A09', 'RN18 - reserva aguardando pagamento já expirada (deveria ter liberado o horário)', count(*)
    FROM agendamento WHERE status = 'Aguardando_pagamento' AND expira_em < timestamptz '2026-11-02 21:30-03'
) t ORDER BY codigo;
-- Observação: A09 pode retornar 1 de propósito — existe 1 reserva pendente cujo prazo de 10 min já passou
--             (é o cenário para demonstrar a rotina que libera horários expirados).

/* =============================================================================
   PARTE 6 — TESTES DAS REGRAS DE INTEGRIDADE
   Cada teste tenta uma operação PROIBIDA. O banco deve recusar (✅). Nada é gravado.
   Os testes marcados [INFORMATIVO] verificam regras que só existem no
   modelo_logico_barbearia.sql (gatilhos) — no script.sql elas ficam a cargo da aplicação.
   Os resultados aparecem na aba "Mensagens" (pgAdmin/DBeaver) ou na tela (psql).
   ============================================================================= */
DO $teste$
DECLARE
  v_ag  agendamento%ROWTYPE;
  v_ok  int := 0; v_fail int := 0; v_info int := 0;
BEGIN
  SELECT * INTO v_ag FROM agendamento WHERE status = 'Confirmado' ORDER BY id_agendamento LIMIT 1;

  -- T01 RN09: dois agendamentos no mesmo horário do mesmo profissional
  BEGIN
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (1, v_ag.id_profissional, v_ag.id_regra_calendario, v_ag.data, v_ag.hora_inicio, v_ag.hora_fim, 'Aguardando_pagamento', 'v1.0', now(), now() + interval '10 minutes');
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T01 NÃO bloqueou sobreposição de horário (RN09)';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T01 RN09 sobreposição bloqueada: %', left(SQLERRM, 90); END IF;
  END;

  -- T02 RN02/RN03: forma de pagamento inválida ("fiado")
  BEGIN
    INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status) VALUES (v_ag.id_agendamento,'Cobranca','Fiado',50,'Pendente');
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T02 aceitou forma "Fiado"';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T02 RN02/RN03 forma de pagamento inválida bloqueada'; END IF;
  END;

  -- T03 avaliação com nota fora de 1..5
  BEGIN
    INSERT INTO avaliacao (id_agendamento, nota) SELECT id_agendamento, 6 FROM agendamento WHERE status = 'Concluido'
      AND id_agendamento NOT IN (SELECT id_agendamento FROM avaliacao) LIMIT 1;
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T03 aceitou nota 6';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T03 nota fora de 1–5 bloqueada'; END IF;
  END;

  -- T04 uma única avaliação por agendamento
  BEGIN
    INSERT INTO avaliacao (id_agendamento, nota) SELECT id_agendamento, 5 FROM avaliacao LIMIT 1;
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T04 aceitou 2ª avaliação';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T04 avaliação duplicada bloqueada'; END IF;
  END;

  -- T05 somente um caixa aberto por vez
  BEGIN
    INSERT INTO fechamento_caixa (id_usuario, aberto_em, saldo_abertura, status) VALUES (1, now(), 0, 'Aberto');
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T05 aceitou 2º caixa aberto';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T05 segundo caixa aberto bloqueado'; END IF;
  END;

  -- T06 RN11: status "Confirmado" exige data de confirmação
  BEGIN
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em)
    VALUES (1,1,2,date '2026-12-01','08:00','08:40','Confirmado','v1.0',now());
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T06 aceitou Confirmado sem confirmado_em';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T06 confirmação sem data bloqueada'; END IF;
  END;

  -- T07 RN12: estorno precisa apontar para o pagamento original
  BEGIN
    INSERT INTO pagamento (id_agendamento,tipo_operacao,forma_pagamento,valor,status,confirmado_em) VALUES (v_ag.id_agendamento,'Estorno','Pix',50,'Pago',now());
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T07 aceitou estorno sem origem';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T07 estorno sem pagamento de origem bloqueado'; END IF;
  END;

  -- T08 preço negativo no catálogo
  BEGIN
    INSERT INTO servico (nome, duracao, preco) VALUES ('Teste', 30, -1);
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T08 aceitou preço negativo';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T08 preço negativo bloqueado'; END IF;
  END;

  -- T09 RN08: não excluir cliente que já tem agendamentos (FK)
  BEGIN
    DELETE FROM cliente WHERE id_cliente = v_ag.id_cliente;
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T09 excluiu cliente com histórico';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T09 exclusão de cliente com histórico bloqueada (inativar em vez de excluir)'; END IF;
  END;

  -- T10 movimento de caixa com duas origens ao mesmo tempo
  BEGIN
    INSERT INTO movimento_caixa (id_usuario,id_pagamento,id_venda,tipo,forma_pagamento,valor)
    VALUES (1,(SELECT min(id_pagamento) FROM pagamento),(SELECT min(id_venda) FROM venda),'Entrada','Pix',10);
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T10 aceitou movimento com 2 origens';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T10 movimento de caixa com origem dupla bloqueado'; END IF;
  END;

  -- T11 venda concluída sem forma de pagamento
  BEGIN
    INSERT INTO venda (id_usuario,status,valor_total,forma_pagamento) VALUES (2,'Concluida',10,NULL);
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T11 aceitou venda concluída sem pagamento';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T11 venda concluída sem forma de pagamento bloqueada'; END IF;
  END;

  -- T12 e-mail inválido
  BEGIN
    INSERT INTO cliente (nome, telefone, email) VALUES ('Teste', '(11) 90000-0000', 'email-invalido');
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T12 aceitou e-mail inválido';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T12 e-mail inválido bloqueado'; END IF;
  END;

  -- T13 hora de término antes do início
  BEGIN
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (1,1,2,date '2026-12-01','10:00','09:00','Aguardando_pagamento','v1.0',now(),now());
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T13 aceitou término antes do início';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T13 hora_fim <= hora_inicio bloqueada'; END IF;
  END;

  -- T14 marketing exige data de consentimento (LGPD / RN17)
  BEGIN
    INSERT INTO cliente (nome, telefone, aceita_marketing) VALUES ('Teste', '(11) 90000-0001', true);
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_fail := v_fail + 1; RAISE NOTICE '❌ T14 aceitou marketing sem data de consentimento';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T14 RN17 marketing sem consentimento registrado bloqueado'; END IF;
  END;

  -- T15 [INFORMATIVO] RN04: agendamento fora do expediente (domingo, 07:00)
  BEGIN
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (1,1,7,date '2026-11-08','07:00','07:40','Aguardando_pagamento','v1.0',now(),now() + interval '10 minutes');
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_info := v_info + 1; RAISE NOTICE '⚠️ T15 [INFORMATIVO] RN04 NÃO é imposta pelo banco (só pela aplicação) — o modelo_logico_barbearia.sql tem gatilho para isso';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T15 RN04 fora do expediente bloqueada: %', left(SQLERRM, 80); END IF;
  END;

  -- T16 [INFORMATIVO] RN11: confirmar sem pagamento aprovado
  BEGIN
    INSERT INTO agendamento (id_cliente,id_profissional,id_regra_calendario,data,hora_inicio,hora_fim,status,politica_reserva_versao,politica_aceita_em,expira_em)
    VALUES (2,1,6,date '2026-12-05','12:00','12:40','Aguardando_pagamento','v1.0',now(),now() + interval '10 minutes');
    UPDATE agendamento SET status = 'Confirmado', confirmado_em = now()
     WHERE id_cliente = 2 AND data = date '2026-12-05' AND hora_inicio = '12:00';
    RAISE EXCEPTION 'NAO_BLOQUEOU';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NAO_BLOQUEOU' THEN v_info := v_info + 1; RAISE NOTICE '⚠️ T16 [INFORMATIVO] RN11 NÃO é imposta pelo banco (confirmou sem serviço/pagamento) — gatilho existe só no modelo_logico_barbearia.sql';
    ELSE v_ok := v_ok + 1; RAISE NOTICE '✅ T16 RN11 confirmação sem pagamento bloqueada: %', left(SQLERRM, 80); END IF;
  END;

  RAISE NOTICE '------------------------------------------------------------';
  RAISE NOTICE 'RESUMO: % bloqueios corretos | % falhas | % informativos', v_ok, v_fail, v_info;
END $teste$;
