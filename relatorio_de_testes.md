# Relatório de testes dos scripts — Barbearia The Family Hair

**Ambiente de teste:** PostgreSQL 16.15 (Ubuntu), banco vazio criado do zero a cada rodada.
**Executado em:** 02/11/2026. Todos os scripts rodaram com `ON_ERROR_STOP=1` (para no primeiro erro).

## 1. O que foi testado e o resultado

| Arquivo | SGBD | Resultado |
|---|---|---|
| `docs/script.sql` | PostgreSQL | ✅ Executa sem erro. Cria schema `barbearia`, 25 tabelas, índices e a view `vw_saldo_estoque`. |
| `docs/modelo_logico_barbearia.sql` | PostgreSQL | ✅ Executa sem erro. Cria 25 tabelas no schema `public`, 6 gatilhos (regras RN04, RN11, RN12, imutabilidade) e a view. |
| `docs/modelo_logico_barbearia_novo.sql` | MySQL 8 | ⚠️ **Não executado** (não havia MySQL disponível). Análise estática: o texto é interpretado como MySQL (147 comandos) e cria as 25 tabelas, **mais 3 tabelas de exemplo que não fazem parte do projeto** (`follows`, `users`, `posts`) e insere dados dessas tabelas de exemplo. |
| `02_popular_banco.sql` (novo) | PostgreSQL | ✅ Executa sem erro em **ambos** os modelos PostgreSQL, com contagens idênticas. |
| `03_testes_e_consultas.sql` (novo) | PostgreSQL | ✅ Sem erros. 14/14 bloqueios de regra no `script.sql` (+2 informativos); 16/16 no modelo com gatilhos. |

## 2. Problemas encontrados nos arquivos do projeto

1. **O `docs/script.sql` só cria a estrutura.** Não tem `INSERT` nem consultas, embora o README (seção 3 e 4) diga que ele "carrega dados fictícios" e traz as consultas G01–G05 e A01…. Essa parte foi escrita nos arquivos 02 e 03.
2. **O README diz "script MySQL", mas o `script.sql` é PostgreSQL** (usa `GENERATED … AS IDENTITY`, `EXCLUDE USING gist`, `timestamptz`). Confirmar com o professor qual SGBD é exigido.
3. **Inconsistência de domínio:** em `registro_higienizacao.resultado` o `script.sql` aceita `'Aprovado'/'Reprovado'`, mas o dicionário de dados e os outros dois scripts definem `'Concluido'/'Reprovado'/'Refeito'`. O script de população detecta qual dos dois está ativo e funciona nos dois casos. Sugestão: alinhar o `script.sql` ao dicionário (linha 201).
4. **Regras só no modelo com gatilhos:** no `script.sql`, RN04 (expediente) e RN11 (confirmar só com serviço e pagamento) não são impostas pelo banco. O teste T15/T16 mostra isso. No `modelo_logico_barbearia.sql` elas são bloqueadas.
5. O README cita `diagrama.png` e a pasta `levantamento/` (com `evidencias/`), que **não estão no zip** (existem `modelo-logico.png` e `fotoEntrevista.jpg`).
6. `modelo_logico_barbearia.sql`: o campo `valor` de `movimento_estoque` do tipo Ajuste não tem sinal (ele mesmo avisa isso). A view `vw_saldo_estoque` ignora ajustes.

## 3. Massa de dados gerada (`02_popular_banco.sql`)

Dados 100% fictícios (nomes inventados, telefones `(11) 95550-00NN`, e-mails `@example.com`). Período: 01/09 a 31/10/2026 (histórico) + agenda de 03 a 07/11/2026. Usa semente fixa: o resultado é reproduzível.

| Tabela | Linhas | Observação |
|---|---:|---|
| usuario_sistema | 6 | 1 administrador, 2 atendimento, 3 profissionais (1 inativado) |
| cliente | 45 | 5 nunca agendaram; alguns sem e-mail; 40% aceitam marketing |
| profissional | 3 | 1 inativo (RN08): Diego, até 09/10; Rafael entra em 13/10 |
| servico / servico_extra | 7 / 3 | 1 serviço inativo (promoção encerrada) |
| regra_calendario | 9 | ter–sáb 08–19h; dom/seg fechados; 2 exceções de feriado |
| agendamento | 482 | 375 concluídos, 45 cancelados, 32 faltas, 29 confirmados, 1 aguardando pagamento |
| agendamento_servico / _extra | 482 / 117 | preço e duração gravados (RN05) |
| pagamento | 550 | cobranças pagas, tentativas que falharam, estornos, 1 pendente |
| avaliacao | 245 | só de atendimentos concluídos, notas de 1 a 5 |
| produto / fornecedor | 16 / 4 | revenda, insumo e "ambos" |
| compra / item_compra | 9 / 35 | recebidas, pedida, cancelada e rascunho |
| venda / item_venda | 56 / 119 | concluídas, canceladas e 1 aberta |
| movimento_estoque | 200 | entradas das compras, saídas de vendas e higienização, ajustes |
| movimento_caixa | 566 | entradas, saídas, estornos e ajustes |
| conta_pagar | 19 | pagas, abertas, 1 atrasada, 1 cancelada |
| fechamento_caixa / _forma | 10 / 36 | 9 semanais fechados + 1 aberto; 3 com diferença de conferência |
| registro_higienizacao | 110 | limpeza, desinfecção, esterilização e descarte; 2 reprovados |
| documento_fiscal | 66 | NFS-e, NFC-e e NF-e (autorizado, pendente, cancelado, recebido) |
| log_auditoria | 77 | logins, falha de login, estornos, exportação, DDL |

## 4. Consultas e auditorias (`03_testes_e_consultas.sql`)

- Volume por tabela; distribuição de status.
- 5 consultas com `JOIN` (J1–J5), `UPDATE`/`DELETE` demonstrativos com `ROLLBACK`.
- Gerenciais **G01–G05** (ocupação, cancelamentos e faltas, atendimentos, estoque abaixo do mínimo, conciliação do caixa) + G06 (clientes sem retorno).
- Auditorias **A01–A09**: A01–A08 retornam 0 violações; **A09 retorna 1 de propósito** (reserva pendente já expirada, para demonstrar RN18).
- 16 testes de regra (T01–T16) que tentam operações proibidas e confirmam o bloqueio.

## 5. Como repetir

```bash
createdb barbearia
psql -v ON_ERROR_STOP=1 -d barbearia -f docs/script.sql
psql -v ON_ERROR_STOP=1 -d barbearia -f docs/02_popular_banco.sql
psql -d barbearia -f docs/03_testes_e_consultas.sql
```

Valores exatos dos exemplos de resultado foram gerados no PostgreSQL 16; em outra versão do PostgreSQL a "aleatoriedade" pode gerar números ligeiramente diferentes, mas todos continuam válidos.
