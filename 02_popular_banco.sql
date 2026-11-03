/* =============================================================================
   Barbearia The Family Hair — POPULAÇÃO DO BANCO (massa de dados fictícia)
   SGBD : PostgreSQL 15+
   Rodar: DEPOIS de docs/script.sql (cria o schema "barbearia" e as 25 tabelas)
          em banco VAZIO. O script é uma única transação: se algo falhar, nada
          fica gravado (ROLLBACK automático) e dá para corrigir e rodar de novo.
   Dados: 100% fictícios (nomes, telefones 95550-xxxx, e-mails @example.com).
   Resultado esperado: ~450 agendamentos (set–nov/2026), pagamentos, estornos,
          vendas de balcão, compras, estoque, contas a pagar, caixa fechado por
          semana (com diferenças), higienização, avaliações, notas fiscais, logs.
   Período: 01/09/2026 a 31/10/2026 (histórico) + agenda de 03 a 07/11/2026.
   ============================================================================= */
BEGIN;
SET search_path TO barbearia, public;

-- Trava de segurança: só popula banco vazio
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cliente) OR EXISTS (SELECT 1 FROM usuario_sistema) THEN
    RAISE EXCEPTION 'O banco já possui dados. Rode em um banco recém-criado (script.sql) ou apague o schema antes.';
  END IF;
  PERFORM setseed(0.2026);   -- mesma "aleatoriedade" em toda execução (resultado reprodutível)
END $do$;

-- Reinicia os contadores de ID (identity não volta atrás em caso de erro; as tabelas já estão vazias aqui)
TRUNCATE usuario_sistema, log_auditoria, cliente, profissional, servico, servico_extra, produto, fornecedor,
         compra, item_compra, venda, item_venda, conta_pagar, fechamento_caixa, fechamento_forma, regra_calendario,
         agendamento, agendamento_servico, agendamento_extra, pagamento, avaliacao, registro_higienizacao,
         movimento_caixa, movimento_estoque, documento_fiscal
  RESTART IDENTITY CASCADE;

/* Função auxiliar temporária (some ao fim da sessão): grava movimento de estoque
   funcionando tanto com o script.sql (FK composta id_compra+id_produto) quanto com
   o modelo_logico_barbearia.sql (colunas id_produto_compra / id_produto_venda). */
CREATE FUNCTION pg_temp.ins_mov_estoque(p_prod int, p_user int, p_compra int, p_venda int, p_higi bigint,
                                        p_tipo text, p_qtd numeric, p_custo numeric, p_ts timestamptz, p_motivo text)
RETURNS void LANGUAGE plpgsql AS $fn$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = to_regclass('movimento_estoque') AND attname = 'id_produto_compra') THEN
    INSERT INTO movimento_estoque(id_produto,id_usuario,id_compra,id_produto_compra,id_venda,id_produto_venda,
                                  id_registro_higienizacao,tipo,quantidade,custo_unitario,data_hora,motivo)
    VALUES (p_prod,p_user,p_compra,CASE WHEN p_compra IS NOT NULL THEN p_prod END,
            p_venda,CASE WHEN p_venda IS NOT NULL THEN p_prod END,p_higi,p_tipo,p_qtd,p_custo,p_ts,p_motivo);
  ELSE
    INSERT INTO movimento_estoque(id_produto,id_usuario,id_compra,id_venda,id_registro_higienizacao,
                                  tipo,quantidade,custo_unitario,data_hora,motivo)
    VALUES (p_prod,p_user,p_compra,p_venda,p_higi,p_tipo,p_qtd,p_custo,p_ts,p_motivo);
  END IF;
END $fn$;

/* =============================================================================
   1. USUÁRIOS DO SISTEMA (6)   — ids 1..6
   ============================================================================= */
INSERT INTO usuario_sistema (nome_exibicao, identificador_login, perfil, ativo, data_criacao, data_desativacao) VALUES
 ('Ana Beatriz Lemos',   'admin.ana',          'Administrador', true,  '2026-08-01 09:00-03', NULL),
 ('Camila Rocha',        'atend.camila',       'Atendimento',   true,  '2026-08-01 09:10-03', NULL),
 ('Juliana Prado',       'atend.juliana',      'Atendimento',   true,  '2026-08-01 09:15-03', NULL),
 ('Thiago Moreira',      'prof.thiago',        'Profissional',  true,  '2026-08-01 09:20-03', NULL),
 ('Diego Albuquerque',   'prof.diego',         'Profissional',  false, '2026-08-01 09:25-03', '2026-10-10 08:00-03'),
 ('Rafael Siqueira',     'prof.rafael',        'Profissional',  true,  '2026-10-12 09:00-03', NULL);

/* =============================================================================
   2. PROFISSIONAIS (3) — Diego foi inativado em 10/10 (RN08: nunca excluir)
   ============================================================================= */
INSERT INTO profissional (nome, especialidade, telefone, ativo) VALUES
 ('Thiago Moreira',    'Corte social e barba',   '(11) 95550-9001', true),
 ('Diego Albuquerque', 'Degradê e acabamento',   '(11) 95550-9002', false),
 ('Rafael Siqueira',   'Barboterapia e pigmentação', '(11) 95550-9003', true);

/* =============================================================================
   3. CATÁLOGO: SERVIÇOS (7) E ADICIONAIS (3)
   ============================================================================= */
INSERT INTO servico (nome, descricao, duracao, preco, ativo) VALUES
 ('Corte Social',            'Corte tradicional na tesoura e máquina',        40, 50.00, true),
 ('Corte Degradê',           'Degradê na máquina com acabamento na navalha',  40, 55.00, true),
 ('Barba',                   'Barba completa com toalha quente',              30, 35.00, true),
 ('Corte + Barba',           'Combo corte e barba',                           60, 80.00, true),
 ('Corte Infantil',          'Corte para crianças até 12 anos',               40, 45.00, true),
 ('Acabamento (Pezinho)',    'Contorno e acabamento do corte',                15, 15.00, true),
 ('Corte Promoção Inauguração', 'Promoção encerrada',                         40, 40.00, false);

INSERT INTO servico_extra (nome, descricao, preco, duracao, ativo) VALUES
 ('Sobrancelha',          'Design de sobrancelha na navalha',    15.00, 10, true),
 ('Hidratação Capilar',   'Hidratação rápida com máscara',       25.00, 15, true),
 ('Pigmentação de Barba', 'Pigmentação para cobrir falhas',      35.00, 20, true);

/* =============================================================================
   4. CLIENTES (45) — telefones fictícios (11) 95550-00NN, e-mails @example.com
   ============================================================================= */
INSERT INTO cliente (nome, telefone, email, data_cadastro, data_atualizacao, ativo, aceita_marketing, data_consentimento_marketing)
SELECT t.nome,
       '(11) 95550-' || lpad(t.n::text, 4, '0'),
       CASE WHEN t.n % 3 = 0 THEN NULL
            ELSE split_part(translate(lower(t.nome),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'),' ',1) || '.' ||
                 (regexp_match(translate(lower(t.nome),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'),'(\S+)$'))[1] || t.n || '@example.com' END,
       CASE WHEN t.n <= 40 THEN timestamptz '2026-08-25 09:00-03' + t.n * interval '10 minutes'
            ELSE timestamptz '2026-10-25 10:00-03' + (t.n - 40) * interval '1 day' END,
       CASE WHEN t.n IN (7, 15, 22) THEN timestamptz '2026-09-30 15:00-03' END,
       (t.n <> 40),
       (t.n % 5 IN (1, 3)),
       CASE WHEN t.n % 5 IN (1, 3) THEN
            (CASE WHEN t.n <= 40 THEN timestamptz '2026-08-25 09:00-03' + t.n * interval '10 minutes'
                  ELSE timestamptz '2026-10-25 10:00-03' + (t.n - 40) * interval '1 day' END) END
FROM (VALUES
 (1,'Carlos Eduardo Nunes'),(2,'Mateus Ribeiro Lopes'),(3,'Gabriel Santana Prado'),(4,'Lucas Henrique Barros'),
 (5,'Pedro Augusto Menezes'),(6,'Felipe Andrade Costa'),(7,'Bruno Vasconcelos Dias'),(8,'Rodrigo Tavares Neto'),
 (9,'André Luiz Cardoso'),(10,'Marcelo Pires Fontes'),(11,'Renan Monteiro Alves'),(12,'Alex Bastos Ferraz'),
 (13,'Leonardo Seixas Moura'),(14,'Vinícius Calazans Rocha'),(15,'Guilherme Rezende Faria'),(16,'Daniel Nogueira Teles'),
 (17,'Eduardo Brandão Leite'),(18,'Fábio Alcântara Reis'),(19,'Henrique Camargo Duarte'),(20,'João Pedro Salgado'),
 (21,'Renato Carvalho Batista'),(22,'Samuel Ferreira Lima'),(23,'Denis Moraes Pacheco'),(24,'Anderson Teixeira Cruz'),
 (25,'Murilo Gouveia Sampaio'),(26,'Caio Vieira Esteves'),(27,'Igor Magalhães Souza'),(28,'Wesley Barreto Araújo'),
 (29,'Otávio Linhares Neves'),(30,'Paulo Sérgio Machado'),(31,'Ricardo Falcão Mendes'),(32,'Sérgio Antunes Borges'),
 (33,'Luan Medeiros Cunha'),(34,'Nathan Coelho Ramos'),(35,'Kaique Domingues Silva'),(36,'Enzo Gabriel Pinheiro'),
 (37,'Davi Lucca Torres'),(38,'Heitor Amaral Franco'),(39,'Bernardo Lage Viana'),(40,'Joaquim Pestana Dutra'),
 (41,'Yuri Sallum Guedes'),(42,'Miguel Arantes Peixoto'),(43,'Théo Bittencourt Lima'),(44,'Gael Fonseca Dias'),
 (45,'Lorenzo Veiga Campos')) AS t(n, nome)
ORDER BY t.n;

/* =============================================================================
   5. CALENDÁRIO (RN04): ids 1..7 = dia da semana ISO (1=seg ... 7=dom); 8 e 9 = exceções
   ============================================================================= */
INSERT INTO regra_calendario (tipo_regra, dia_semana, data_especifica, situacao, hora_abertura, hora_fechamento, vigencia_inicio, vigencia_fim, motivo, ativo) VALUES
 ('SEMANAL',1,NULL,'FECHADO',NULL,NULL,'2026-01-01',NULL,'Segunda-feira fechado',true),
 ('SEMANAL',2,NULL,'ABERTO','08:00','19:00','2026-01-01',NULL,NULL,true),
 ('SEMANAL',3,NULL,'ABERTO','08:00','19:00','2026-01-01',NULL,NULL,true),
 ('SEMANAL',4,NULL,'ABERTO','08:00','19:00','2026-01-01',NULL,NULL,true),
 ('SEMANAL',5,NULL,'ABERTO','08:00','19:00','2026-01-01',NULL,NULL,true),
 ('SEMANAL',6,NULL,'ABERTO','08:00','19:00','2026-01-01',NULL,NULL,true),
 ('SEMANAL',7,NULL,'FECHADO',NULL,NULL,'2026-01-01',NULL,'Domingo fechado',true),
 ('EXCECAO',NULL,'2026-10-12','ABERTO','09:00','14:00','2026-10-12','2026-10-12','Feriado (N. Sra. Aparecida): abre em horário reduzido',true),
 ('EXCECAO',NULL,'2026-11-20','FECHADO',NULL,NULL,'2026-11-20','2026-11-20','Feriado (Consciência Negra): fechado',true);

/* =============================================================================
   6. PRODUTOS (16), FORNECEDORES (4)
   ============================================================================= */
INSERT INTO produto (nome, tipo_produto, unidade_medida, sku, descricao, preco_venda, ativo, estoque_minimo) VALUES
 ('Pomada Modeladora Efeito Matte 150g','Revenda','un','POM-MAT-150','Fixação forte, efeito seco',        42.90,true,6),
 ('Pomada Brilho Forte 150g',           'Revenda','un','POM-BRI-150','Fixação forte, alto brilho',        39.90,true,6),
 ('Cera Modeladora 100g',               'Revenda','un','CER-MOD-100','Fixação média',                     34.90,true,5),
 ('Óleo para Barba 30ml',               'Revenda','un','OLE-BAR-030','Hidratação e brilho para barba',    49.90,true,5),
 ('Balm Pós-Barba 80g',                 'Revenda','un','BAL-POS-080','Calmante pós-barba',                44.90,true,4),
 ('Shampoo para Barba 200ml',           'Revenda','un','SHA-BAR-200','Limpeza de barba',                  36.90,true,4),
 ('Shampoo Anticaspa 250ml',            'Revenda','un','SHA-ANT-250','Controle de caspa',                 32.90,true,4),
 ('Gel Fixador Extra Forte 300g',       'Revenda','un','GEL-FIX-300','Gel de fixação extra forte',        19.90,true,6),
 ('Pente de Madeira',                   'Revenda','un','PEN-MAD-001','Pente antiestático de madeira',     24.90,true,3),
 ('Pó Texturizador 10g',                'Ambos',  'un','PO-TEX-010', 'Usado em serviços e vendido',       29.90,true,3),
 ('Lâmina Descartável (cx c/ 100)',     'Insumo', 'cx','LAM-DES-100','Lâminas de barbear descartáveis',   NULL,true,2),
 ('Álcool 70% 1L',                      'Insumo', 'l', 'ALC-070-1L', 'Desinfecção de superfícies e máquinas', NULL,true,5),
 ('Desinfetante de Superfícies 1L',     'Insumo', 'l', 'DES-SUP-1L', 'Limpeza de bancadas e cadeiras',    NULL,true,3),
 ('Capa Descartável (pct c/ 50)',       'Insumo', 'pct','CAP-DES-050','Capas de proteção de uso único',   NULL,true,3),
 ('Toalha Descartável (pct c/ 100)',    'Insumo', 'pct','TOA-DES-100','Toalhas de uso único',             NULL,true,3),
 ('Espuma de Barbear 200ml',            'Insumo', 'un','ESP-BAR-200','Espuma para barbear na cadeira',    NULL,true,6);

INSERT INTO fornecedor (nome_razao_social, documento_fiscal, telefone, email, ativo) VALUES
 ('Distribuidora Fio de Navalha Ltda',   '10.000.001/0001-00', '(11) 4000-0001', 'vendas@example.com',   true),
 ('Cosméticos Barba Forte Comércio',     '10.000.002/0001-00', '(11) 4000-0002', 'pedidos@example.com',  true),
 ('Higiene Pro Suprimentos',             '10.000.003/0001-00', '(11) 4000-0003', 'contato@example.com',  true),
 ('Atacado Beleza Central',              '10.000.004/0001-00', '(11) 4000-0004', NULL,                   true);

/* =============================================================================
   7. COMPRAS E ITENS (9 compras) + ENTRADAS DE ESTOQUE (só das recebidas, RN13)
   ============================================================================= */
INSERT INTO compra (id_fornecedor, id_usuario, data_pedido, status, data_recebimento, observacao) VALUES
 (1,1,'2026-08-25 10:00-03','Recebida','2026-08-27 14:00-03','Estoque inicial de pomadas e acessórios'),
 (2,1,'2026-08-25 10:30-03','Recebida','2026-08-28 11:00-03','Estoque inicial de barba'),
 (3,1,'2026-08-26 09:00-03','Recebida','2026-08-29 10:00-03','Insumos de higiene'),
 (1,1,'2026-09-22 10:00-03','Recebida','2026-09-24 15:00-03','Reposição de pomadas'),
 (2,1,'2026-10-06 10:00-03','Recebida','2026-10-08 11:30-03','Reposição de barba'),
 (3,1,'2026-10-13 09:30-03','Recebida','2026-10-15 10:00-03','Reposição de insumos'),
 (1,1,'2026-10-30 09:00-03','Pedida',   NULL,                  'Aguardando entrega do fornecedor'),
 (4,1,'2026-10-20 16:00-03','Cancelada',NULL,                  'Cancelada: preço acima do combinado'),
 (2,1,'2026-11-02 18:00-03','Rascunho', NULL,                  'Pedido em elaboração');

INSERT INTO item_compra (id_compra, id_produto, quantidade, custo_unitario) VALUES
 (1, 1,12,24.00),(1, 2,12,22.00),(1, 3,14,19.00),(1, 8,15,10.50),(1, 9,17,12.00),(1,10,14,16.00),
 (2, 4,14,28.00),(2, 5, 8,25.00),(2, 6,11,20.00),(2, 7,20,18.00),
 (3,11, 4,85.00),(3,12,12,14.00),(3,13, 8,11.00),(3,14, 6,28.00),(3,15, 6,32.00),(3,16,12, 9.00),
 (4, 1, 8,24.50),(4, 2, 6,22.50),(4, 3, 6,19.50),(4, 8,10,10.50),
 (5, 4, 4,28.50),(5, 5, 8,25.50),(5, 6, 3,20.50),
 (6,11, 3,86.00),(6,12, 8,14.50),(6,14, 4,28.50),(6,15, 4,32.50),(6,16, 8, 9.00),
 (7, 1,10,25.00),(7, 2,10,23.00),(7, 9, 6,12.50),
 (8, 7,10,21.00),(8,10, 5,18.00),
 (9, 4, 8,29.00),(9, 5, 6,26.00);

UPDATE compra c SET valor_total = COALESCE((SELECT sum(quantidade * custo_unitario) FROM item_compra i WHERE i.id_compra = c.id_compra), 0);

DO $do$
DECLARE r record;
BEGIN
  FOR r IN SELECT i.id_compra, i.id_produto, i.quantidade, i.custo_unitario, c.data_recebimento
             FROM item_compra i JOIN compra c USING (id_compra)
            WHERE c.status = 'Recebida' ORDER BY c.data_recebimento, i.id_produto
  LOOP
    PERFORM pg_temp.ins_mov_estoque(r.id_produto, 1, r.id_compra, NULL, NULL, 'Entrada', r.quantidade, r.custo_unitario, r.data_recebimento, NULL);
  END LOOP;
END $do$;

/* =============================================================================
   8. AGENDAMENTOS + SERVIÇOS + EXTRAS + PAGAMENTOS + ESTORNOS + CAIXA + AVALIAÇÕES
   Regras respeitadas: RN04 (expediente), RN05 (preço/duração gravados), RN07 (cancelamento
   tardio <2h), RN09 (sem sobreposição), RN11 (pagamento integral p/ confirmar),
   RN12 (estorno sem apagar pagamento original), RN18 (reserva expira em 10 min).
   ============================================================================= */
CREATE TEMP TABLE tmp_prof_janela (id_profissional int, ini date, fim date) ON COMMIT DROP;
INSERT INTO tmp_prof_janela VALUES (1,'2026-09-01','2026-12-31'),   -- Thiago: todo o período
                                   (2,'2026-09-01','2026-10-09'),   -- Diego: até ser inativado
                                   (3,'2026-10-13','2026-12-31');   -- Rafael: entra em 13/10

DO $do$
DECLARE
  d date; rg record; p record; i int; h int; v_slots int[]; v_n int;
  v_start time; v_end time; v_dur int; v_ts_ini timestamptz;
  v_svc int; v_svc_dur int; v_svc_price numeric(10,2);
  v_ext int; v_ext_dur int; v_ext_price numeric(10,2); v_total numeric(10,2);
  v_cli int; v_r double precision; v_status text; v_forma text;
  v_paid timestamptz; v_created timestamptz; v_cancel timestamptz;
  v_future boolean; v_pending boolean; v_expired boolean; v_attempt boolean; v_tardio boolean;
  v_ag int; v_pay int; v_user int; v_nota int; v_motivo text;
  v_formas text[]  := ARRAY['Pix','Pix','Credito','Debito','Dinheiro','Pix','Credito','Debito'];
  v_motivos text[] := ARRAY['Imprevisto no trabalho','Cliente doente','Problema de transporte','Vai remarcar para outro dia','Sem motivo informado'];
  v_comentarios text[] := ARRAY['Atendimento demorou mais que o combinado.','Poderia melhorar a pontualidade.',
                                'Bom corte, ambiente agradável.','Ótimo atendimento, recomendo!','Excelente! Melhor barbearia da região.'];
BEGIN
  FOR d IN SELECT g::date FROM generate_series(date '2026-09-01', date '2026-11-07', interval '1 day') g LOOP
    SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'EXCECAO' AND data_especifica = d AND ativo;
    IF NOT FOUND THEN
      SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'SEMANAL' AND dia_semana = EXTRACT(ISODOW FROM d)::int AND ativo;
    END IF;
    CONTINUE WHEN rg.situacao <> 'ABERTO';
    v_future := d > date '2026-11-02';

    FOR p IN SELECT * FROM tmp_prof_janela WHERE d BETWEEN ini AND fim ORDER BY id_profissional LOOP
      v_n := CASE WHEN v_future THEN 3 ELSE 4 + floor(random()*3)::int END;      -- 4 a 6 atendimentos por profissional/dia
      SELECT array_agg(s ORDER BY random()) INTO v_slots
        FROM generate_series(EXTRACT(HOUR FROM rg.hora_abertura)::int, EXTRACT(HOUR FROM rg.hora_fechamento)::int - 1) s;
      v_n := least(v_n, array_length(v_slots, 1));

      FOR i IN 1..v_n LOOP
        h := v_slots[i];
        v_start := make_time(h, 0, 0);

        -- serviço principal (+ adicional opcional que caiba em 60 min)
        v_r := random();
        v_svc := CASE WHEN v_r < .25 THEN 1 WHEN v_r < .50 THEN 2 WHEN v_r < .65 THEN 3
                      WHEN v_r < .85 THEN 4 WHEN v_r < .93 THEN 5 ELSE 6 END;
        SELECT duracao, preco INTO v_svc_dur, v_svc_price FROM servico WHERE id_servico = v_svc;
        v_ext := NULL; v_ext_dur := NULL; v_ext_price := NULL;
        IF random() < 0.30 THEN
          SELECT id_extra, duracao, preco INTO v_ext, v_ext_dur, v_ext_price
            FROM servico_extra WHERE ativo AND duracao <= 60 - v_svc_dur ORDER BY random() LIMIT 1;
        END IF;
        v_ext_dur := COALESCE(v_ext_dur, 0); v_ext_price := COALESCE(v_ext_price, 0);
        v_dur := v_svc_dur + v_ext_dur;
        v_total := v_svc_price + v_ext_price;
        v_end := v_start + make_interval(mins => v_dur);
        v_ts_ini := (d + v_start) AT TIME ZONE 'America/Sao_Paulo';

        -- cliente: após 20/09 só os 32 clientes "fiéis"; clientes 41-45 são novos (nunca agendaram)
        v_cli := CASE WHEN d < date '2026-09-20' THEN 1 + floor(random()*40)::int ELSE 1 + floor(random()*32)::int END;

        -- desfecho
        v_pending := (d = date '2026-11-07' AND p.id_profissional = 1 AND i = 1);
        v_r := random();
        v_status := CASE WHEN v_pending THEN 'Aguardando_pagamento'
                         WHEN v_future THEN 'Confirmado'
                         WHEN v_r < .74 THEN 'Concluido'
                         WHEN v_r < .86 THEN 'Cancelado'
                         WHEN v_r < .93 THEN 'Faltou'
                         ELSE 'Concluido' END;
        v_expired := (v_status = 'Cancelado' AND random() < 0.20);          -- reserva que expirou sem pagar
        v_attempt := (NOT v_expired AND NOT v_pending AND random() < 0.10);  -- 1ª tentativa no crédito falhou
        v_forma   := CASE WHEN v_attempt THEN 'Pix' ELSE v_formas[1 + floor(random()*8)::int] END;
        v_user    := 2 + floor(random()*2)::int;                             -- Camila ou Juliana

        v_paid := greatest(v_ts_ini - make_interval(hours => 3 + floor(random()*45)::int), timestamptz '2026-08-31 08:00-03');
        v_paid := least(v_paid, timestamptz '2026-11-02 20:00-03');
        v_paid := date_trunc('minute', v_paid);
        v_created := CASE WHEN v_pending THEN timestamptz '2026-11-02 21:10-03' ELSE v_paid - interval '8 minutes' END;

        IF v_status = 'Cancelado' THEN
          v_tardio := (NOT v_expired AND random() < 0.35);
          IF v_expired THEN
            v_cancel := v_created + interval '10 minutes';
            v_motivo := 'Reserva expirada sem pagamento (10 min)';
          ELSE
            IF v_tardio THEN v_cancel := v_ts_ini - make_interval(mins => 30 + floor(random()*80)::int);
            ELSE v_cancel := v_paid + interval '1 minute' + ((v_ts_ini - interval '2 hours 5 minutes') - v_paid - interval '1 minute') * random();
            END IF;
            v_cancel := date_trunc('minute', v_cancel);
            v_motivo := v_motivos[1 + floor(random()*5)::int];
          END IF;
        ELSE
          v_tardio := false; v_cancel := NULL; v_motivo := NULL;
        END IF;

        INSERT INTO agendamento (id_cliente, id_profissional, id_regra_calendario, data, hora_inicio, hora_fim, status,
                                 politica_reserva_versao, politica_aceita_em, criado_em, expira_em, confirmado_em, checkin_em,
                                 cancelado_em, motivo_cancelamento, observacao)
        VALUES (v_cli, p.id_profissional, rg.id_regra_calendario, d, v_start, v_end, v_status,
                'v1.0', v_created, v_created, v_created + interval '10 minutes',
                CASE WHEN v_expired OR v_pending THEN NULL ELSE v_paid END,
                CASE WHEN v_status = 'Concluido' THEN v_ts_ini - make_interval(mins => floor(random()*13)::int - 2) END,
                v_cancel,
                CASE WHEN v_status = 'Cancelado' THEN v_motivo END,
                CASE WHEN random() < 0.08 THEN 'Cliente prefere máquina nº 2' END)
        RETURNING id_agendamento INTO v_ag;

        INSERT INTO agendamento_servico VALUES (v_ag, v_svc, v_svc_price, v_svc_dur);
        IF v_ext IS NOT NULL THEN
          INSERT INTO agendamento_extra VALUES (v_ag, v_ext, v_ext_price, v_ext_dur);
        END IF;

        -- pagamentos
        IF v_pending THEN
          INSERT INTO pagamento (id_agendamento, tipo_operacao, forma_pagamento, valor, status, criado_em, referencia_provedor, chave_idempotencia)
          VALUES (v_ag, 'Cobranca', 'Pix', v_total, 'Pendente', v_created, 'PIX-' || lpad(v_ag::text,6,'0') || '-P', 'idem-' || v_ag || '-1');
        ELSE
          IF v_attempt OR v_expired THEN
            INSERT INTO pagamento (id_agendamento, tipo_operacao, forma_pagamento, valor, status, criado_em, referencia_provedor, chave_idempotencia)
            VALUES (v_ag, 'Cobranca', 'Credito', v_total, 'Falhou', v_created + interval '2 minutes',
                    'CRE-' || lpad(v_ag::text,6,'0') || '-F', 'idem-' || v_ag || '-1');
          END IF;
          IF NOT v_expired THEN
            INSERT INTO pagamento (id_agendamento, tipo_operacao, forma_pagamento, valor, status, criado_em, confirmado_em, referencia_provedor, chave_idempotencia)
            VALUES (v_ag, 'Cobranca', v_forma, v_total, 'Pago', v_paid - interval '1 minute', v_paid,
                    CASE WHEN v_forma = 'Dinheiro' THEN NULL ELSE upper(left(v_forma,3)) || '-' || lpad(v_ag::text,6,'0') || '-P' END,
                    'idem-' || v_ag || '-2')
            RETURNING id_pagamento INTO v_pay;
            INSERT INTO movimento_caixa (id_usuario, id_pagamento, tipo, forma_pagamento, valor, data_hora)
            VALUES (v_user, v_pay, 'Entrada', v_forma, v_total, v_paid);

            IF v_status = 'Cancelado' AND NOT v_tardio THEN        -- cancelou com >= 2h: estorno integral
              INSERT INTO pagamento (id_agendamento, id_pagamento_origem, tipo_operacao, forma_pagamento, valor, status, criado_em, confirmado_em, referencia_provedor, chave_idempotencia)
              VALUES (v_ag, v_pay, 'Estorno', v_forma, v_total, 'Pago', v_cancel + interval '1 minute', v_cancel + interval '3 minutes',
                      CASE WHEN v_forma = 'Dinheiro' THEN NULL ELSE upper(left(v_forma,3)) || '-' || lpad(v_ag::text,6,'0') || '-E' END,
                      'idem-' || v_ag || '-est')
              RETURNING id_pagamento INTO v_pay;
              INSERT INTO movimento_caixa (id_usuario, id_pagamento, tipo, forma_pagamento, valor, data_hora, motivo)
              VALUES (v_user, v_pay, 'Estorno', v_forma, v_total, v_cancel + interval '3 minutes', 'Estorno por cancelamento com antecedência >= 2h');
            END IF;
          END IF;
        END IF;

        -- avaliação (só de atendimento concluído)
        IF v_status = 'Concluido' AND random() < 0.60 THEN
          v_r := random();
          v_nota := CASE WHEN v_r < .50 THEN 5 WHEN v_r < .80 THEN 4 WHEN v_r < .92 THEN 3 WHEN v_r < .97 THEN 2 ELSE 1 END;
          INSERT INTO avaliacao (id_agendamento, nota, comentario, data_avaliacao)
          VALUES (v_ag, v_nota, CASE WHEN random() < .5 THEN v_comentarios[v_nota] END,
                  ((d + v_end) AT TIME ZONE 'America/Sao_Paulo') + (1 + floor(random()*10)::int) * interval '3 hours');
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
END $do$;

/* =============================================================================
   9. VENDAS DE BALCÃO + ITENS + SAÍDAS DE ESTOQUE + ENTRADAS NO CAIXA
   ============================================================================= */
DO $do$
DECLARE
  d date; rg record; k int; v_n int; v_r double precision; v_h int; v_ts timestamptz;
  v_venda int; v_user int; v_cli int; v_forma text; v_total numeric(10,2); v_status text;
  pr record; v_qtd numeric; v_desc numeric(10,2); v_saldo numeric; v_items int; v_nit int;
  v_formas text[] := ARRAY['Pix','Pix','Credito','Debito','Dinheiro','Pix','Debito','Dinheiro'];
BEGIN
  FOR d IN SELECT g::date FROM generate_series(date '2026-09-01', date '2026-10-31', interval '1 day') g LOOP
    SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'EXCECAO' AND data_especifica = d AND ativo;
    IF NOT FOUND THEN
      SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'SEMANAL' AND dia_semana = EXTRACT(ISODOW FROM d)::int AND ativo;
    END IF;
    CONTINUE WHEN rg.situacao <> 'ABERTO';

    v_r := random();
    v_n := CASE WHEN v_r < .20 THEN 0 WHEN v_r < .55 THEN 1 ELSE 2 END;
    FOR k IN 1..v_n LOOP
      v_h  := EXTRACT(HOUR FROM rg.hora_abertura)::int + floor(random() * (EXTRACT(HOUR FROM rg.hora_fechamento)::int - EXTRACT(HOUR FROM rg.hora_abertura)::int))::int;
      v_ts := (d + make_time(v_h, floor(random()*60)::int, 0)) AT TIME ZONE 'America/Sao_Paulo';
      v_user := 2 + floor(random()*2)::int;
      v_cli  := CASE WHEN random() < .6 THEN 1 + floor(random()*32)::int END;
      v_nit  := 1 + floor(random()*3)::int;
      v_items := 0; v_total := 0;

      INSERT INTO venda (id_usuario, id_cliente, data_hora, status, valor_total, forma_pagamento)
      VALUES (v_user, v_cli, v_ts, 'Aberta', 0, NULL) RETURNING id_venda INTO v_venda;

      v_status := CASE WHEN random() < .92 THEN 'Concluida' ELSE 'Cancelada' END;
      v_forma  := v_formas[1 + floor(random()*8)::int];

      FOR pr IN SELECT id_produto, preco_venda FROM produto
                 WHERE tipo_produto IN ('Revenda','Ambos') AND ativo ORDER BY random() LIMIT v_nit
      LOOP
        v_qtd  := CASE WHEN random() < .8 THEN 1 ELSE 2 END;
        v_desc := CASE WHEN random() < .08 THEN round(pr.preco_venda * 0.10, 2) END;
        SELECT COALESCE(SUM(CASE WHEN tipo = 'Entrada' AND data_hora <= v_ts THEN quantidade
                                 WHEN tipo = 'Saida' THEN -quantidade ELSE 0 END), 0)
          INTO v_saldo FROM movimento_estoque WHERE id_produto = pr.id_produto;
        CONTINUE WHEN v_saldo < v_qtd;                      -- nunca vende além do saldo (RN13)
        INSERT INTO item_venda (id_venda, id_produto, quantidade, preco_unitario, desconto_unitario)
        VALUES (v_venda, pr.id_produto, v_qtd, pr.preco_venda, v_desc);
        v_items := v_items + 1;
        v_total := v_total + v_qtd * (pr.preco_venda - COALESCE(v_desc, 0));
        IF v_status = 'Concluida' THEN
          PERFORM pg_temp.ins_mov_estoque(pr.id_produto, v_user, NULL, v_venda, NULL, 'Saida', v_qtd, NULL, v_ts, NULL);
        END IF;
      END LOOP;

      IF v_items = 0 THEN
        DELETE FROM venda WHERE id_venda = v_venda;
      ELSE
        UPDATE venda SET status = v_status, valor_total = v_total,
                         forma_pagamento = CASE WHEN v_status = 'Concluida' THEN v_forma END
         WHERE id_venda = v_venda;
        IF v_status = 'Concluida' THEN
          INSERT INTO movimento_caixa (id_usuario, id_venda, tipo, forma_pagamento, valor, data_hora)
          VALUES (v_user, v_venda, 'Entrada', v_forma, v_total, v_ts);
        END IF;
      END IF;
    END LOOP;
  END LOOP;
END $do$;

-- Uma venda ainda aberta (balcão, hoje 02/11) — não baixa estoque nem entra no caixa
INSERT INTO venda (id_usuario, id_cliente, data_hora, status, valor_total, forma_pagamento)
VALUES (2, 7, '2026-11-02 18:40-03', 'Aberta', 94.80, NULL);
INSERT INTO item_venda (id_venda, id_produto, quantidade, preco_unitario, desconto_unitario)
SELECT currval(pg_get_serial_sequence('venda','id_venda')), 4, 1, 49.90, NULL::numeric
UNION ALL
SELECT currval(pg_get_serial_sequence('venda','id_venda')), 5, 1, 44.90, NULL::numeric;

/* =============================================================================
   10. HIGIENIZAÇÃO (RN15) + consumo de insumos (saída de estoque ligada ao registro)
   ============================================================================= */
DO $do$
DECLARE
  d date; rg record; v_reg bigint; v_user int; v_ts timestamptz; v_res text; v_obs text; v_ok text;
BEGIN
  -- O script.sql aceita 'Aprovado'; o dicionário de dados e o modelo_logico_barbearia.sql aceitam 'Concluido'
  v_ok := CASE WHEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('registro_higienizacao')
                              AND pg_get_constraintdef(oid) LIKE '%Aprovado%') THEN 'Aprovado' ELSE 'Concluido' END;
  FOR d IN SELECT g::date FROM generate_series(date '2026-09-01', date '2026-10-31', interval '1 day') g LOOP
    SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'EXCECAO' AND data_especifica = d AND ativo;
    IF NOT FOUND THEN
      SELECT * INTO rg FROM regra_calendario WHERE tipo_regra = 'SEMANAL' AND dia_semana = EXTRACT(ISODOW FROM d)::int AND ativo;
    END IF;
    CONTINUE WHEN rg.situacao <> 'ABERTO';
    v_user := CASE WHEN d <= date '2026-10-09' THEN (ARRAY[4,5])[1 + floor(random()*2)::int]
                   ELSE (ARRAY[4,6])[1 + floor(random()*2)::int] END;
    v_ts := (d + rg.hora_fechamento - interval '30 minutes') AT TIME ZONE 'America/Sao_Paulo';

    INSERT INTO registro_higienizacao (id_usuario, data_hora, item_area, etapa, metodo, resultado)
    VALUES (v_user, v_ts, 'Cadeiras e bancadas', 'Limpeza', 'Remoção de resíduos e pano úmido com desinfetante', v_ok);

    v_res := CASE WHEN d IN (date '2026-10-09', date '2026-10-21') THEN 'Reprovado' ELSE v_ok END;
    v_obs := CASE WHEN v_res = 'Reprovado' THEN 'Resíduos encontrados na máquina; processo refeito' END;
    INSERT INTO registro_higienizacao (id_usuario, data_hora, item_area, etapa, metodo, produto_lote, resultado, observacao)
    VALUES (v_user, v_ts + interval '10 minutes', 'Máquinas de corte e navalhas', 'Desinfeccao',
            'Pulverização de álcool 70% e secagem', 'ALC70-L' || to_char(d,'YYMM'), v_res, v_obs)
    RETURNING id_registro INTO v_reg;
    PERFORM pg_temp.ins_mov_estoque(12, v_user, NULL, NULL, v_reg, 'Saida', 0.250, NULL, v_ts + interval '10 minutes', NULL);

    IF EXTRACT(ISODOW FROM d) = 6 THEN
      INSERT INTO registro_higienizacao (id_usuario, data_hora, item_area, etapa, metodo, referencia_ciclo, resultado)
      VALUES (v_user, v_ts + interval '20 minutes', 'Tesouras e alicates', 'Esterilizacao',
              'Autoclave: ciclo padrão do fabricante', 'AUT-' || to_char(d,'YYYYMMDD') || '-01', v_ok);
      INSERT INTO registro_higienizacao (id_usuario, data_hora, item_area, etapa, metodo, resultado)
      VALUES (v_user, v_ts + interval '25 minutes', 'Lâminas usadas', 'Descarte',
              'Descarte em coletor para perfurocortantes', v_ok)
      RETURNING id_registro INTO v_reg;
      PERFORM pg_temp.ins_mov_estoque(11, v_user, NULL, NULL, v_reg, 'Saida', 0.100, NULL, v_ts + interval '25 minutes', NULL);
    END IF;
  END LOOP;
END $do$;

-- Ajustes de estoque (exigem motivo e responsável — RN13)
DO $do$
BEGIN
  PERFORM pg_temp.ins_mov_estoque(4, 1, NULL, NULL, NULL, 'Ajuste', 1, NULL, '2026-10-20 17:00-03', 'Frasco avariado no transporte (perda)');
  PERFORM pg_temp.ins_mov_estoque(9, 1, NULL, NULL, NULL, 'Ajuste', 1, NULL, '2026-10-27 17:30-03', 'Divergência na contagem de inventário');
  PERFORM pg_temp.ins_mov_estoque(12,1, NULL, NULL, NULL, 'Ajuste', 0.5, NULL, '2026-10-29 18:00-03', 'Vazamento de galão');
END $do$;

/* =============================================================================
   11. CONTAS A PAGAR + SAÍDAS DO CAIXA
   ============================================================================= */
INSERT INTO conta_pagar (id_fornecedor, id_compra, id_usuario, descricao, categoria, valor, data_vencimento, status, data_baixa)
SELECT c.id_fornecedor, c.id_compra, 1, 'Compra #' || c.id_compra || ' - ' || f.nome_razao_social, 'Fornecedor', c.valor_total,
       (ARRAY['2026-09-05','2026-09-05','2026-09-05','2026-10-04','2026-10-18','2026-10-25','2026-11-15','2026-10-30'])[c.id_compra]::date,
       CASE WHEN c.id_compra <= 6 THEN 'Paga' WHEN c.id_compra = 7 THEN 'Aberta' ELSE 'Cancelada' END,
       CASE c.id_compra WHEN 1 THEN timestamptz '2026-09-03 10:00-03' WHEN 2 THEN '2026-09-03 10:05-03' WHEN 3 THEN '2026-09-03 10:10-03'
                        WHEN 4 THEN '2026-10-02 10:00-03' WHEN 5 THEN '2026-10-16 10:00-03' WHEN 6 THEN '2026-10-24 10:00-03' END
  FROM compra c JOIN fornecedor f USING (id_fornecedor)
 WHERE c.status <> 'Rascunho' ORDER BY c.id_compra;

INSERT INTO conta_pagar (id_fornecedor, id_compra, id_usuario, descricao, categoria, valor, data_vencimento, status, data_baixa) VALUES
 (NULL,NULL,1,'Aluguel - setembro/2026',        'Aluguel', 2400.00,'2026-09-05','Paga',    '2026-09-04 09:00-03'),
 (NULL,NULL,1,'Aluguel - outubro/2026',         'Aluguel', 2400.00,'2026-10-05','Paga',    '2026-10-05 09:00-03'),
 (NULL,NULL,1,'Aluguel - novembro/2026',        'Aluguel', 2400.00,'2026-11-05','Aberta',  NULL),
 (NULL,NULL,1,'Energia elétrica - setembro',    'Energia',  180.50,'2026-09-12','Paga',    '2026-09-11 10:00-03'),
 (NULL,NULL,1,'Energia elétrica - outubro',     'Energia',  205.30,'2026-10-12','Paga',    '2026-10-12 10:00-03'),
 (NULL,NULL,1,'Energia elétrica - novembro',    'Energia',  195.00,'2026-11-12','Aberta',  NULL),
 (NULL,NULL,1,'Água - outubro',                 'Água',      98.40,'2026-10-20','Paga',    '2026-10-19 10:00-03'),
 (NULL,NULL,1,'Internet - setembro',            'Internet', 119.90,'2026-09-28','Paga',    '2026-09-28 10:00-03'),
 (NULL,NULL,1,'Internet - outubro',             'Internet', 119.90,'2026-10-28','Atrasada',NULL),
 (NULL,NULL,2,'Material de limpeza (pago no caixa)','Limpeza', 45.90,'2026-09-17','Paga', '2026-09-17 11:00-03'),
 (NULL,NULL,2,'Café e copa (pago no caixa)',    'Copa',      62.00,'2026-10-22','Paga',    '2026-10-22 15:00-03');

INSERT INTO movimento_caixa (id_usuario, id_conta, tipo, forma_pagamento, valor, data_hora, motivo)
SELECT id_usuario, id_conta, 'Saida',
       CASE WHEN categoria IN ('Limpeza','Copa') THEN 'Dinheiro' ELSE 'Nao_aplicavel' END,   -- boleto/transferência: fora do caixa físico
       valor, data_baixa, NULL
  FROM conta_pagar WHERE status = 'Paga' ORDER BY data_baixa;

-- Ajustes de caixa que explicam as diferenças dos fechamentos (RN14: só por lançamento novo)
INSERT INTO movimento_caixa (id_usuario, tipo, forma_pagamento, valor, data_hora, motivo) VALUES
 (2,'Ajuste','Dinheiro',10.00,'2026-09-18 14:00-03','Nota de R$ 10,00 falsa recebida no troco'),
 (3,'Ajuste','Dinheiro', 5.00,'2026-10-02 12:00-03','Sobra de caixa sem origem identificada'),
 (2,'Ajuste','Pix',     20.00,'2026-10-09 16:00-03','Pix recebido sem identificação - conciliar com extrato');

/* =============================================================================
   12. FECHAMENTOS DE CAIXA (semanais, ter–sáb) + CONFERÊNCIA POR FORMA
   ============================================================================= */
INSERT INTO fechamento_caixa (id_usuario, aberto_em, fechado_em, saldo_abertura, status)
SELECT 1,
       ((date '2026-08-31' + 7*k + 1) + time '08:00') AT TIME ZONE 'America/Sao_Paulo',
       ((date '2026-08-31' + 7*k + 5) + time '19:30') AT TIME ZONE 'America/Sao_Paulo',
       200.00, 'Fechado'
  FROM generate_series(0, 8) k;

UPDATE movimento_caixa m
   SET id_fechamento = (SELECT f.id_fechamento FROM fechamento_caixa f WHERE f.fechado_em >= m.data_hora ORDER BY f.fechado_em LIMIT 1)
 WHERE m.data_hora <= timestamptz '2026-10-31 19:30-03';

INSERT INTO fechamento_forma (id_fechamento, forma_pagamento, valor_esperado, valor_conferido)
SELECT f.id_fechamento, fp.forma, x.esperado, x.esperado
  FROM fechamento_caixa f
 CROSS JOIN (VALUES ('Pix'),('Credito'),('Debito'),('Dinheiro')) fp(forma)
 CROSS JOIN LATERAL (
        SELECT COALESCE(SUM(CASE m.tipo WHEN 'Entrada' THEN m.valor WHEN 'Estorno' THEN -m.valor WHEN 'Saida' THEN -m.valor ELSE 0 END), 0)
               + CASE WHEN fp.forma = 'Dinheiro' THEN f.saldo_abertura ELSE 0 END AS esperado
          FROM movimento_caixa m WHERE m.id_fechamento = f.id_fechamento AND m.forma_pagamento = fp.forma) x;

-- Diferenças reais de conferência (explicadas pelos ajustes acima)
UPDATE fechamento_forma SET valor_conferido = valor_esperado - 10.00 WHERE id_fechamento = 3 AND forma_pagamento = 'Dinheiro';
UPDATE fechamento_forma SET valor_conferido = valor_esperado +  5.00 WHERE id_fechamento = 5 AND forma_pagamento = 'Dinheiro';
UPDATE fechamento_forma SET valor_conferido = valor_esperado - 20.00 WHERE id_fechamento = 6 AND forma_pagamento = 'Pix';

-- Caixa da semana corrente (único aberto permitido)
INSERT INTO fechamento_caixa (id_usuario, aberto_em, fechado_em, saldo_abertura, status)
VALUES (2, '2026-11-02 08:00-03', NULL, 200.00, 'Aberto');

/* =============================================================================
   13. DOCUMENTOS FISCAIS (referências fictícias; não calculam tributos)
   ============================================================================= */
INSERT INTO documento_fiscal (id_agendamento, tipo, numero, serie, chave_acesso, emitido_em, status, localizador_arquivo)
SELECT a.id_agendamento, 'NFS-e', lpad(row_number() OVER (ORDER BY a.id_agendamento)::text, 6, '0'), 'A1', NULL,
       ((a.data + a.hora_fim) AT TIME ZONE 'America/Sao_Paulo') + interval '10 minutes', 'Autorizado',
       'nfse/ag-' || a.id_agendamento || '.pdf'
  FROM agendamento a WHERE a.status = 'Concluido' AND a.id_agendamento % 8 = 0;

INSERT INTO documento_fiscal (id_venda, tipo, numero, serie, chave_acesso, emitido_em, status, localizador_arquivo)
SELECT v.id_venda, 'NFC-e', lpad(row_number() OVER (ORDER BY v.id_venda)::text, 6, '0'), '1',
       '35261000000100000000650010' || lpad(row_number() OVER (ORDER BY v.id_venda)::text, 9, '0') || '1' || '0000000' || '0',
       v.data_hora + interval '1 minute', 'Autorizado', 'nfce/venda-' || v.id_venda || '.xml'
  FROM venda v WHERE v.status = 'Concluida' AND v.id_venda % 5 = 0;

UPDATE documento_fiscal SET status = 'Cancelado' WHERE tipo = 'NFS-e' AND numero = '000003';
UPDATE documento_fiscal SET status = 'Pendente'  WHERE tipo = 'NFC-e' AND numero = '000002';

INSERT INTO documento_fiscal (id_compra, tipo, numero, serie, chave_acesso, emitido_em, status, localizador_arquivo)
SELECT c.id_compra, 'NF-e', 'F-' || lpad((1000 + c.id_compra)::text, 6, '0'), '1',
       '35260810000001000100550010' || lpad((1000 + c.id_compra)::text, 9, '0') || '1' || '0000000' || '0',
       c.data_recebimento, 'Recebido', 'nfe/compra-' || c.id_compra || '.xml'
  FROM compra c WHERE c.status = 'Recebida';

/* =============================================================================
   14. LOG DE AUDITORIA (RF11)
   ============================================================================= */
INSERT INTO log_auditoria (id_usuario, data_hora, acao, componente, recurso, resultado, identificador_registro, origem, id_correlacao, data_expurgo_prevista)
SELECT 2 + (EXTRACT(DOY FROM g)::int % 2), (g + time '07:55') AT TIME ZONE 'America/Sao_Paulo', 'LOGIN', 'APLICACAO', 'sessao', 'SUCESSO',
       NULL, 'app-web', 'sess-' || to_char(g, 'YYYYMMDD'), (g + 1825)::date
  FROM (SELECT x::date FROM generate_series(date '2026-09-01', date '2026-10-31', interval '1 day') x) t(g)
 WHERE EXTRACT(ISODOW FROM g) BETWEEN 2 AND 6;

INSERT INTO log_auditoria (id_usuario, data_hora, acao, componente, recurso, resultado, identificador_registro, origem, id_correlacao, data_expurgo_prevista)
SELECT 2, p.confirmado_em, 'ESTORNO', 'APLICACAO', 'pagamento', 'SUCESSO', p.id_pagamento::text, 'app-web', 'est-' || p.id_pagamento, (p.confirmado_em::date + 1825)
  FROM pagamento p WHERE p.tipo_operacao = 'Estorno';

INSERT INTO log_auditoria (id_usuario, data_hora, acao, componente, recurso, resultado, identificador_registro, origem, principal_sgbd, id_sessao_sgbd, data_expurgo_prevista) VALUES
 (2,'2026-09-14 07:50-03','LOGIN_FALHA','APLICACAO','sessao','FALHA',NULL,'app-web',NULL,NULL,'2031-09-13'),
 (1,'2026-09-30 17:00-03','ALTERACAO_PERMISSAO','APLICACAO','usuario_sistema','SUCESSO','5','app-web',NULL,NULL,'2031-09-29'),
 (1,'2026-10-10 08:00-03','DML','APLICACAO','usuario_sistema','SUCESSO','5','app-web',NULL,NULL,'2031-10-09'),
 (1,'2026-10-12 09:00-03','DML','APLICACAO','usuario_sistema','SUCESSO','6','app-web',NULL,NULL,'2031-10-11'),
 (1,'2026-10-31 20:00-03','EXPORTACAO','APLICACAO','fechamento_caixa','SUCESSO','9','app-web',NULL,NULL,'2031-10-30'),
 (1,'2026-10-20 18:00-03','DDL','SGBD','schema barbearia','SUCESSO',NULL,'psql','postgres','pid-4412','2031-10-19');

COMMIT;
ANALYZE;
