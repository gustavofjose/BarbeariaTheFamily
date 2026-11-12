# Sistema de Gestão da Barbearia The Family Hair

## Equipe

| Integrante | RGM | Usuário GitHub |
|---|---:|---|
| Antonio Dantas da Silva Neto | 47788356 | AntonioDS |
| Arthur de Jesus Salviano Oliveira | 47764988 | arthurjso12-dev |
| Gustavo Frutuoso José | 47604565 | gustavofjose |
| Heitor Tureck de Oliveira | 47104503 | syndaflod |
| Lucas Ramon Bezerra Gomes | 47766263 | LucasGomes609 |

## Identificação da organização

<img src="levantamento/evidencias/entrevista-no-local.jpg" width="250" alt="Entrevista realizada na Barbearia The Family Hair" />

- **Nome fantasia:** The Family Hair
- **Razão social:** 61.946.399 William Loreilhe
- **CNPJ:** 61.946.399/0001-92
- **Endereço:** Rua Sonho Gaúcho, 352, Jardim São Nicolau, São Paulo, SP, CEP 03685-000
- **Telefone:** (11) 98520-6485

## 1. Relatório Técnico Final

Este projeto especifica a base de dados de gestão da Barbearia The Family Hair. O sistema organiza agenda e atendimento e reúne os registros de clientes, profissionais, serviços, pagamentos, vendas, compras, estoque e caixa. Os dados estruturados apoiam a operação diária e a análise gerencial.

### 1.1 Revisão do Modelo Conceitual

#### Caracterização da organização

A The Family Hair é uma barbearia de pequeno porte situada na Rua Sonho Gaúcho, 352, Jardim São Nicolau, São Paulo, SP. O repositório guarda a foto feita no local, o endereço, o telefone, a razão social e o CNPJ. O levantamento inicial registra duas cadeiras e cita o barbeiro Victor. O sistema foi preparado para mais de um profissional, pois a agenda precisa identificar quem realizará cada atendimento.

O problema central é P1, a organização dos horários quando há cancelamento, atraso ou falta. O modelo também trata P2, a falta de um histórico único para pagamentos e atendimentos, e P3, o acompanhamento de produtos, compras, estoque, contas a pagar e caixa. No [`script.sql`](docs/script.sql), P1 é respondido por G01, G02, G08 e G10; P2 por S01, G03, G06 e G11; P3 por S02, G04, G05, G07 e G09 (ver a tabela de rastreabilidade da seção 1.6).

O escopo reúne os dados de agenda, atendimento, pagamentos, produtos, compras, estoque e financeiro. Assim, o projeto não fica restrito ao agendamento. Detalhes que ainda dependem da confirmação do responsável, como pagamento antecipado, tolerância de atraso e a rotina atual de estoque, estão identificados no levantamento e não são apresentados como fatos da operação.

#### Entrevista e levantamento

A visita presencial ocorreu em 21/10/2026, às 19h10, e foi registrada na foto disponível em [levantamento/evidencias/entrevista-no-local.jpg](levantamento/evidencias/entrevista-no-local.jpg). O resumo do levantamento está em [levantamento/levantamento.md](levantamento/levantamento.md). Foram entrevistados William Loreilhe, proprietário e barbeiro, e Victor Pugaciov, barbeiro e filho do proprietário. Lucas Ramon Bezerra Gomes participou da visita pelo grupo.

Na visita foi observado o atendimento em uma estrutura de duas cadeiras. O grupo levantou a necessidade de organizar a agenda e registrar ocorrências que afetam o horário reservado. Para completar a validação, as perguntas sobre o fluxo atual de marcação, pagamento, atrasos, venda de produtos, compras, estoque e caixa permanecem listadas no levantamento.

#### Processos de negócio

Os processos abaixo descrevem o fluxo que o banco deve registrar. Cada um tem um código (PN01 a PN14), citado no cabeçalho das consultas do script SQL. Onde a prática da barbearia ainda não foi confirmada, a regra está marcada como proposta de sistema e precisa da validação indicada no levantamento.

**PN01 — Cadastro e identificação do cliente.** No primeiro atendimento, registrar somente nome, telefone necessário para contato e, se desejado, e-mail; conferir os dados com o titular, explicar o uso operacional e não condicionar o serviço à aceitação de propaganda. Buscar duplicidade pelo telefone, permitir correção e registrar data de criação/atualização. Marketing requer opção separada, revogável e registrada.

**PN02 — Escolha de serviço e extras.** O cliente escolhe um ou mais serviços ativos de `SERVICO` e adicionais opcionais de `SERVICO_EXTRA`. Gravar as escolhas em `AGENDAMENTO_SERVICO` e `AGENDAMENTO_EXTRA`, mostrar descrição, duração, preço unitário e total antes da confirmação. Um agendamento confirmado precisa de ao menos um serviço principal; FK sozinha não garante isso.

**PN03 — Profissional, data e horário.** Oferecer profissionais ativos e consultar `REGRA_CALENDARIO` para os dias e horários semanais, além das exceções publicadas pela barbearia, incluindo feriados abertos ou fechados. Validar que início e término caibam no expediente e verificar conflito por profissional com intervalos sobrepostos, inclusive em operações simultâneas. A premissa inicial é terça a sábado, das 08:00 às 19:00, com domingo e segunda fechados.

**PN04 — Pagamento durante o agendamento.** O banco registra forma, valor, status e data/hora da tentativa de pagamento. Pix, cartão e dinheiro são formas previstas no modelo. A exigência de pagamento integral para confirmar a reserva e o prazo de dez minutos para uma reserva pendente são propostas do sistema; o responsável deve confirmar se há sinal ou pagamento antecipado na prática.

**PN05 — Confirmação e lembretes.** Em uma transação, persistir agendamento, serviços/extras, preço contratado, pagamento confirmado e movimento financeiro. Só então mudar para Confirmado e emitir recibo/comprovante; o documento fiscal aplicável segue a rotina definida com a contabilidade. Enviar confirmação e lembretes de 24 h e 1 h pelos canais escolhidos, sem usar esses avisos para marketing.

**PN06 — Chegada, tolerância e atendimento.** Registrar chegada, início e conclusão do atendimento. A proposta é registrar atraso, falta e remarcação, sem apagar o agendamento. A tolerância de dez minutos e a marcação de falta após quinze minutos sem contato ainda precisam ser confirmadas com o responsável.

**PN07 — Execução e higiene entre clientes.** Conferir serviço contratado, realizar atendimento e registrar conclusão. Entre clientes, remover resíduos e fazer limpeza/desinfecção adequada; instrumentos reutilizáveis que exijam esterilização devem seguir instruções do fabricante e normas sanitárias locais, com registro de etapa, responsável, horário e resultado. Materiais de uso único não são reprocessados.

**PN08 — Cancelamento, remarcação e falta.** Registrar solicitante, data/hora, motivo, antecedência e resultado da solicitação. A proposta de permitir remarcação ou reembolso com duas horas de antecedência não é uma regra confirmada da barbearia. O responsável deve definir a prática para cancelamento próximo do horário, falta, crédito e estorno.

**PN09 — Venda de produtos no balcão.** Identificar produto, quantidade, preço, desconto autorizado e total; concluir venda em `VENDA`/`ITEM_VENDA`, receber por Pix, crédito, débito ou dinheiro e gerar saída de estoque na mesma transação. Cliente é opcional para venda de balcão. Nunca permitir saldo negativo sem ajuste autorizado e auditado.

**PN10 — Compras e reposição de estoque.** Responsável cadastra fornecedor, registra pedido/compra, itens, quantidades e custos em `COMPRA`/`ITEM_COMPRA`, confere mercadoria e documento do fornecedor no recebimento e só então atualiza o estoque. Divergências, perdas, validade/lote quando pertinente e devoluções são registradas; não editar saldo sem trilha.

**PN11 — Contas a pagar e caixa.** Lançar obrigações com fornecedor, origem, vencimento, valor e status; alertar vencimentos e registrar cada baixa. `MOVIMENTO_CAIXA` mantém entradas/saídas por origem e forma; abertura/fechamento registra saldo inicial, esperado, contado e diferença por dinheiro, Pix e cartões. Conferir relatórios do adquirente/banco, justificar divergências e impedir alteração de caixa já fechado sem estorno/auditoria.

**PN12 — Documento fiscal.** Associar documentos emitidos às vendas e aos atendimentos, além dos documentos recebidos nas compras. A necessidade de emissão, o tipo de documento e a guarda devem ser confirmados com a contabilidade da organização.

**PN13 — Relatórios e avaliação.** Fechar agenda e caixa por período, profissional e forma de pagamento; acompanhar ocupação, cancelamentos/faltas, vendas, margem, giro e estoque mínimo. Após atendimento concluído, permitir uma avaliação por agendamento, sem publicar comentário pessoal sem revisão e finalidade adequada.

**PN14 — Gestão de acessos, auditoria e direitos.** Conceder acesso individual por função, desativar contas no desligamento e registrar alterações relevantes. O banco limita os dados de clientes ao necessário para contato e atendimento; a política de retenção precisa ser definida pela organização.

#### Requisitos funcionais

- **RF01, clientes:** cadastrar e atualizar nome, telefone e e-mail opcional; manter o status do cadastro e evitar duplicidade conforme a regra definida para telefone.
- **RF02, profissionais:** cadastrar profissionais e controlar sua situação ativa sem excluir atendimentos anteriores.
- **RF03, catálogo:** cadastrar serviços e adicionais com nome, descrição, duração, preço e situação ativa.
- **RF04, agendamentos:** registrar cliente, profissional, data, início, término, status e observação opcional; associar um ou mais serviços e zero ou mais adicionais.
- **RF05, disponibilidade:** consultar calendário e agenda, calcular a duração total e impedir sobreposição de horários do mesmo profissional.
- **RF06, pagamentos:** registrar tentativas, forma, valor, status, data/hora e relação com agendamento; manter estorno como operação referenciada ao pagamento original.
- **RF07, atendimento e avaliação:** atualizar o status do atendimento e aceitar avaliação somente após conclusão.
- **RF08, produtos e compras:** registrar fornecedores, compras, vendas e respectivos itens; atualizar o estoque após recebimento ou venda concluída.
- **RF09, financeiro:** registrar contas a pagar, movimentos de caixa e fechamento por forma de pagamento.
- **RF10, consultas:** produzir consultas gerenciais e de auditoria para agenda, cancelamentos, atendimentos, pagamentos, estoque e caixa.
- **RF11, auditoria:** registrar o usuário responsável por alterações relevantes de agenda, estoque e caixa.

#### Requisitos não funcionais

- **RNF01, privacidade:** limitar a coleta de dados pessoais ao necessário para cadastro, agendamento e atendimento.
- **RNF02, segurança:** controlar acesso por usuário e não armazenar dados completos de cartão, CVV, senhas ou credenciais.
- **RNF03, integridade:** aplicar PK, FK e restrições de domínio; usar transações nas confirmações de agendamento, pagamento, venda, compra e fechamento.
- **RNF04, desempenho:** a consulta de disponibilidade deve responder em menos de dois segundos nas condições previstas para a operação.
- **RNF05, usabilidade:** permitir consulta e atualização rápida da agenda durante os atendimentos.
- **RNF06, disponibilidade:** permitir solicitações de agendamento fora do horário de atendimento; a meta técnica de disponibilidade deve ser definida na implantação.

#### Regras operacionais

| Código | Regra |
|---|---|
| RN01 | Todo atendimento está vinculado a um agendamento. |
| RN02 | Não é permitido realizar atendimentos com pagamento pendente após a conclusão do serviço. O atendimento deve respeitar a política de pagamento definida pela barbearia. |
| RN03 | As formas de pagamento previstas são Pix, crédito, débito e dinheiro. |
| RN04 | O expediente regular configurado é de terça a sábado, das 08h às 19h; domingo e segunda-feira ficam fechados. Aberturas ou fechamentos em feriados são exceções do calendário. |
| RN05 | Duração e preço aceitos ficam registrados no item do agendamento. As referências de catálogo são 40 minutos para corte e 60 minutos quando há adicional. |
| RN06 | A meta de oito a nove cortes por profissional em um dia de funcionamento é indicador de capacidade, não limite automático de reservas. |
| RN07 | Cancelamentos feitos com menos de duas horas de antecedência ficam registrados no histórico. |
| RN08 | Profissionais, serviços e adicionais podem ser inativados sem excluir o histórico relacionado. |
| RN09 | Um profissional não pode ter agendamentos confirmados com horários sobrepostos. |
| RN10 | A tolerância de atraso é configurável; chegada, status e eventual falta ficam registrados no agendamento. |
| RN11 | A política do projeto prevê pagamento integral para confirmar a reserva. O sistema registra tentativas separadas e confirma somente após aprovação. |
| RN12 | Remarcação, crédito ou estorno ficam registrados sem apagar o pagamento original. O sistema não aplica multa automática por falta. |
| RN13 | Compras aumentam o estoque após recebimento e conferência; vendas concluídas reduzem o estoque. Ajustes exigem motivo e responsável. |
| RN14 | Movimentos de caixa fechados não são sobrescritos; correções são feitas por lançamentos rastreáveis. |
| RN18 | A reserva aguardando pagamento expira após dez minutos e libera o horário. Pagamentos confirmados depois da expiração são conciliados antes de nova cobrança ou estorno. |

As regras RN10, RN11, RN12 e RN18 são parâmetros propostos para o sistema e precisam ser validadas com o responsável. As demais regras devem ser conferidas com a rotina observada antes da implantação.

#### Restrições organizacionais, legais e de privacidade

| Código | Restrição | Aplicação no sistema |
|---|---|---|
| RN15 | Higienização/desinfecção entre atendimentos e esterilização quando aplicável. | Registrar procedimento e responsável de acordo com instruções do fabricante e normas sanitárias competentes; o sistema não define parâmetros técnicos de esterilização. |
| RN16 | Documentos fiscais, tributos e prazos de guarda dependem do enquadramento da organização. | `DOCUMENTO_FISCAL` guarda somente número, data, tipo e status do documento. A obrigatoriedade de emissão deve ser confirmada com a contabilidade; o sistema não calcula tributos. |
| RN17 | Dados pessoais precisam de finalidade, controle de acesso e período de retenção; marketing é separado e opcional. | Coletar o mínimo necessário e restringir o acesso. A política de retenção será definida pela organização antes da implantação. |

#### Pontos a confirmar com o cliente

1. **Nota fiscal:** confirmar com a contabilidade se a operação exige emissão de documento fiscal e qual tipo deve ser registrado. O sistema mantém apenas a referência do documento, sem cálculo tributário.
2. **Retenção de dados:** definir, antes da implantação, o prazo e o destino dos dados pessoais após esse período: exclusão, anonimização ou guarda por obrigação legal.
3. **Higiene:** `REGISTRO_HIGIENIZACAO` é uma proposta de controle do sistema, baseada nas normas sanitárias aplicáveis. A rotina efetivamente adotada pela barbearia ainda deve ser confirmada com William ou Victor.

#### Entidades e relacionamentos conceituais

O modelo conceitual possui 25 entidades/tabelas. Cliente e profissional se relacionam a agendamentos; cada agendamento pertence a um cliente e a um profissional. A relação N:N entre agendamento e serviço é resolvida por `AGENDAMENTO_SERVICO`; serviços adicionais opcionais usam `AGENDAMENTO_EXTRA`. Pagamentos mantêm tentativas e estornos; avaliações se relacionam a atendimentos concluídos. Compras e vendas se relacionam a produtos por itens próprios, e movimentos registram as alterações de estoque e caixa.

| Área | Entidades |
|---|---|
| Agenda e atendimento | `CLIENTE`, `PROFISSIONAL`, `AGENDAMENTO`, `AGENDAMENTO_SERVICO`, `AGENDAMENTO_EXTRA`, `SERVICO`, `SERVICO_EXTRA`, `AVALIACAO` |
| Pagamento e auditoria | `PAGAMENTO`, `USUARIO_SISTEMA`, `LOG_AUDITORIA` |
| Produtos e compras | `PRODUTO`, `FORNECEDOR`, `COMPRA`, `ITEM_COMPRA`, `VENDA`, `ITEM_VENDA`, `MOVIMENTO_ESTOQUE` |
| Financeiro e documentos | `CONTA_PAGAR`, `MOVIMENTO_CAIXA`, `FECHAMENTO_CAIXA`, `FECHAMENTO_FORMA`, `DOCUMENTO_FISCAL` |
| Operação e calendário | `REGISTRO_HIGIENIZACAO`, `REGRA_CALENDARIO` |

**Cardinalidades principais:**

| Relacionamento | Cardinalidades mín./máx. |
|---|---|
| `CLIENTE` e `AGENDAMENTO` | Cliente `(0,N)`; agendamento `(1,1)`. |
| `PROFISSIONAL` e `AGENDAMENTO` | Profissional `(0,N)`; agendamento `(1,1)`. |
| `AGENDAMENTO` e `SERVICO` | N:N por `AGENDAMENTO_SERVICO`; agendamento confirmado exige ao menos um serviço. |
| `AGENDAMENTO` e `SERVICO_EXTRA` | N:N por `AGENDAMENTO_EXTRA`; extras são opcionais. |
| `AGENDAMENTO` e `PAGAMENTO` | Agendamento `(0,N)`; cada tentativa pertence a um agendamento `(1,1)`. |
| `AGENDAMENTO` e `AVALIACAO` | Agendamento `(0,1)`; avaliação pertence a um agendamento concluído `(1,1)`. |
| `COMPRA` e `PRODUTO` | N:N por `ITEM_COMPRA`, com quantidade e custo praticado. |
| `VENDA` e `PRODUTO` | N:N por `ITEM_VENDA`, com quantidade e preço praticado. |

**DER conceitual:** [diagrama do modelo conceitual](diagramas/der-conceitual.png). O diagrama representa entidades, atributos, identificadores, relacionamentos, entidades associativas e cardinalidades mínimas/máximas nos dois lados. Foi elaborado no brModelo.

#### Correções da primeira entrega

| Apontamento da correção | Alteração realizada | Motivo |
|---|---|---|
| Organização e entrevista sem evidência | Foto da visita, endereço, telefone, CNPJ e levantamento foram incluídos no repositório. | Permitir conferir a existência da organização e o acesso do grupo. |
| Processos restritos ao agendamento | Foram incluídos cadastro, atendimento, pagamento, cancelamento, vendas, compras, estoque, contas a pagar, caixa e higiene. | O banco representa a operação inteira. |
| Regras sem separação | Regras operacionais e restrições organizacionais ficaram em seções separadas. | Distinguir a rotina do negócio de obrigações legais e sanitárias. |
| Dicionário não era um dicionário | Foi criado [docs/dicionario-de-dados.html](docs/dicionario-de-dados.html), com atributos, tipos, obrigatoriedade, descrição e regras. | Documentar o modelo de forma verificável. |
| DER sem mínimas, associativas e entidades descritas | O DER revisado apresenta cardinalidades mínimas/máximas, `SERVICO_EXTRA`, `AGENDAMENTO_SERVICO`, `AGENDAMENTO_EXTRA`, produtos e associativas de compra e venda. | Representar os relacionamentos N:N e os dados históricos dos itens. |
| FK no DER conceitual e ligação quebrada | O DER conceitual usa identificadores, atributos e relacionamentos; PK e FK estão no modelo lógico. | Separar os níveis conceitual e lógico. |
| Justificativa divergente do diagrama | A justificativa foi alinhada aos diagramas e ao dicionário atuais. | Evitar entidades ou regras descritas sem representação no modelo. |

### 1.2 Conversão do modelo conceitual para o modelo lógico

- Cada entidade persistente foi convertida em tabela relacional.
- Atributos atômicos foram convertidos em colunas com tipos definidos no dicionário.
- Relacionamentos 1:N foram implementados com FK no lado N, como `AGENDAMENTO.id_cliente` e `AGENDAMENTO.id_profissional`.
- Relacionamentos N:N foram convertidos em tabelas associativas: `AGENDAMENTO_SERVICO`, `AGENDAMENTO_EXTRA`, `ITEM_COMPRA`, `ITEM_VENDA` e `FECHAMENTO_FORMA`.
- Atributos que descrevem uma transação, como quantidade, preço praticado e duração acordada, ficam nos itens correspondentes para preservar o histórico.
- O modelo atual não utiliza generalização/especialização.

### 1.3 Chaves primárias e estrangeiras

| Tabela | Chave primária | Chaves estrangeiras |
|---|---|---|
| `CLIENTE` | `id_cliente` | Nenhuma |
| `PROFISSIONAL` | `id_profissional` | Nenhuma |
| `AGENDAMENTO` | `id_agendamento` | `id_cliente`, `id_profissional`, `id_regra_calendario` |
| `AGENDAMENTO_SERVICO` | `id_agendamento`, `id_servico` | `AGENDAMENTO`, `SERVICO` |
| `AGENDAMENTO_EXTRA` | `id_agendamento`, `id_extra` | `AGENDAMENTO`, `SERVICO_EXTRA` |
| `SERVICO` | `id_servico` | Nenhuma |
| `SERVICO_EXTRA` | `id_extra` | Nenhuma |
| `PAGAMENTO` | `id_pagamento` | `id_agendamento`, `id_pagamento_origem` (autorrelacionamento de estorno) |
| `AVALIACAO` | `id_avaliacao` | `id_agendamento` (único) |
| `USUARIO_SISTEMA` | `id_usuario` | Nenhuma |
| `LOG_AUDITORIA` | `id_log` | `id_usuario` |
| `PRODUTO` | `id_produto` | Nenhuma |
| `FORNECEDOR` | `id_fornecedor` | Nenhuma |
| `COMPRA` | `id_compra` | `id_fornecedor`, `id_usuario` |
| `ITEM_COMPRA` | `id_compra`, `id_produto` | `COMPRA`, `PRODUTO` |
| `VENDA` | `id_venda` | `id_usuario`, `id_cliente` (opcional) |
| `ITEM_VENDA` | `id_venda`, `id_produto` | `VENDA`, `PRODUTO` |
| `CONTA_PAGAR` | `id_conta` | `id_fornecedor` (opcional), `id_compra` (opcional), `id_usuario` |
| `MOVIMENTO_CAIXA` | `id_movimento` | `id_usuario`, `id_pagamento`, `id_venda`, `id_conta`, `id_fechamento` (origens opcionais conforme o tipo) |
| `FECHAMENTO_CAIXA` | `id_fechamento` | `id_usuario` |
| `FECHAMENTO_FORMA` | `id_fechamento`, `forma_pagamento` | `FECHAMENTO_CAIXA` |
| `MOVIMENTO_ESTOQUE` | `id_mov_estoque` | `id_produto`, `id_usuario`, origem em item de compra/venda ou higienização |
| `DOCUMENTO_FISCAL` | `id_documento` | Uma origem entre `AGENDAMENTO`, `VENDA` e `COMPRA` |
| `REGISTRO_HIGIENIZACAO` | `id_registro` | `id_usuario` |
| `REGRA_CALENDARIO` | `id_regra_calendario` | Nenhuma |

### 1.4 Processo de normalização (1FN, 2FN e 3FN)

- **1FN:** cada coluna contém um valor atômico. Serviços de uma reserva, adicionais, produtos de compra/venda e formas de pagamento não são armazenados como listas; são representados em tabelas associativas.
- **2FN:** atributos de tabelas com chave composta dependem da chave completa. Em `ITEM_COMPRA`, quantidade e custo praticado dependem do par compra-produto; os dados descritivos do produto permanecem em `PRODUTO`. O mesmo princípio é aplicado aos itens de venda e de serviço.
- **3FN:** dados de clientes, profissionais, serviços, produtos e fornecedores ficam em suas próprias tabelas. As tabelas transacionais mantêm referências e os valores históricos necessários, evitando dependências transitivas e preservando o que foi aceito na operação.

### 1.5 Justificativas técnicas

- Identificadores `id_*` são chaves estáveis e não dependem de atributos que podem mudar, como nome, telefone ou descrição.
- Chaves compostas nas tabelas associativas impedem a repetição do mesmo item na mesma transação e representam relações N:N.
- A separação entre agendamento e itens permite incluir vários serviços, adicionais opcionais e preservar preço/duração acordados.
- Pagamentos são separados de agendamentos para registrar tentativas, aprovações e estornos sem apagar a transação original.
- Avaliação tem vínculo único com agendamento para limitar a uma avaliação por atendimento concluído.
- Movimentos de estoque e caixa guardam cada entrada/saída, em vez de sobrescrever somente um saldo; isso permite auditoria e reconstrução histórica.
- FKs asseguram que as referências existam. Sobreposição temporal, presença mínima de itens e origem exclusiva de movimentos exigem validação transacional e restrições compatíveis com MySQL.
- `NOT NULL`, `UNIQUE`, `CHECK` e `DEFAULT` documentam e implementam as regras operacionais RN01 a RN18.
- Serviços, adicionais e profissionais são inativados em vez de excluídos, mantendo a integridade de operações passadas.

### 1.6 Proposta analítica para BI e IA

**KPIs propostos** (cada um calculado por uma consulta do script):

| KPI | Fórmula | Período | Meta | Consulta |
|---|---|---|---|---|
| Taxa de perda da agenda | (faltas + cancelamentos) / agendamentos | mês | até 10% | G08 |
| Atendimentos por profissional por dia | atendimentos concluídos / dias com atendimento | mês | 8 por dia (RN06) | G10 |
| Ticket médio dos atendimentos | receita de serviços e adicionais / atendimentos concluídos | mês | acompanhar a evolução mensal | G11 |
| Produtos abaixo do estoque mínimo | quantidade de produtos com saldo < estoque mínimo | dia | zero produtos | G04 |
| Diferença de caixa | valor conferido − valor esperado, por forma de pagamento | fechamento | R$ 0,00 | G05 |

**Rastreabilidade** (problema ou KPI → tabelas → consulta no [`script.sql`](docs/script.sql)):

| Problema ou KPI | Tabelas envolvidas | Consulta no script |
|---|---|---|
| P1 — situação da agenda (concluídos, cancelados, faltas) | `AGENDAMENTO` | G01 |
| P1 — agenda por data, profissional, serviços e valor contratado | `AGENDAMENTO`, `CLIENTE`, `PROFISSIONAL`, `AGENDAMENTO_SERVICO`, `SERVICO`, `AGENDAMENTO_EXTRA`, `SERVICO_EXTRA` | G02 |
| P1 / KPI — taxa mensal de faltas e cancelamentos | `AGENDAMENTO` | G08 |
| P1 / KPI — atendimentos por profissional por dia | `AGENDAMENTO`, `PROFISSIONAL` | G10 |
| P2 — histórico de atendimentos e pagamentos do cliente | `CLIENTE`, `AGENDAMENTO`, `PROFISSIONAL`, `AGENDAMENTO_SERVICO`, `SERVICO`, `PAGAMENTO` | S01 |
| P2 — receita e nota média por profissional e serviço | `AGENDAMENTO`, `PROFISSIONAL`, `AGENDAMENTO_SERVICO`, `SERVICO`, `AVALIACAO` | G03 |
| P2 — valor líquido e estornos por forma de pagamento | `PAGAMENTO` | G06 |
| P2 / KPI — ticket médio e receita mensal | `AGENDAMENTO`, `AGENDAMENTO_SERVICO`, `AGENDAMENTO_EXTRA` | G11 |
| P3 — compras por fornecedor e produto | `COMPRA`, `FORNECEDOR`, `ITEM_COMPRA`, `PRODUTO` | S02 |
| P3 / KPI — produtos abaixo do estoque mínimo | `PRODUTO`, `MOVIMENTO_ESTOQUE` (visão `vw_saldo_estoque`) | G04 |
| P3 / KPI — diferença no fechamento de caixa | `FECHAMENTO_CAIXA`, `FECHAMENTO_FORMA` | G05 |
| P3 — produtos mais vendidos no balcão | `VENDA`, `ITEM_VENDA`, `PRODUTO` | G07 |
| P3 — contas a pagar atrasadas e a vencer | `CONTA_PAGAR`, `FORNECEDOR` | G09 |

**Auditorias** (resultado esperado: 0 violações):

| Código | Verifica | Regra |
|---|---|---|
| A01 | Horários sobrepostos do mesmo profissional | RN09 |
| A02 | Agendamento confirmado/concluído sem pagamento integral | RN02, RN11 |
| A03 | Produto com saldo de estoque negativo | RN13 |
| A04 | Mais de um caixa aberto | RN14 |
| A05 | Agendamento sem serviço principal | RN01, RN05 |
| A06 | Avaliação de atendimento não concluído | RF07 |
| A07 | Estorno maior que o pagamento original | RN12 |

Os testes T01 a T05 tentam gravar dados inválidos e confirmam que o banco bloqueia (RN09, RN03, RF07, RN14 e RN17). Um painel pode apresentar agenda, cancelamentos, atendimentos, estoque e caixa. Previsão de faltas ou recomendação de horários só deve ser considerada quando houver histórico suficiente e uma política de privacidade definida.

## 2. Modelo Lógico Relacional

O modelo lógico é apresentado em [diagrama do modelo lógico](diagramas/modelo-logico.png), elaborado no brModelo. Ele contém tabelas, colunas e tipos, PK, FK e cardinalidades convertidas. As demais restrições de integridade estão no dicionário e no script SQL.

## 3. Script SQL Completo

São dois arquivos para MySQL 8.0.16 ou superior, na pasta [`docs/`](docs/):

- [`script.sql`](docs/script.sql): script completo, executado do zero em um banco vazio. Segue esta ordem: CREATE DATABASE e CREATE TABLE (parte 1); constraints UNIQUE e FK (parte 2); gatilhos, eventos e visão (parte 3); carga da massa com INSERT INTO (parte 4); SELECT com JOIN V01, S01 e S02 (parte 5); UPDATE U01 a U03 (parte 6); DELETE D01 e D02 (parte 7); consultas gerenciais G01 a G11 (parte 8); auditorias A01 a A07 (parte 9); e testes de regras T01 a T05 (parte 10). Cada consulta tem um cabeçalho com o código, a pergunta que responde e o que atende (problema P1 a P3 e processo PN, ou regra RN).
- [`massa-de-dados.sql`](docs/massa-de-dados.sql): a mesma carga da parte 4, em arquivo separado. Ela limpa as tabelas antes de inserir e serve para recarregar os dados sem recriar o banco.

O passo a passo de execução está em [COMO_EXECUTAR.md](COMO_EXECUTAR.md).

## 4. Massa de Dados

A massa é fictícia e reproduz os processos modelados sem utilizar dados reais de clientes. Ela cobre dez semanas de operação, de 01/09/2026 a 07/11/2026, com datas fixas para que qualquer pessoa obtenha os mesmos resultados.

**Como o porte justifica o volume.** A barbearia tem duas cadeiras e funciona de terça a sábado. A massa considera dois profissionais ativos com cinco atendimentos agendados por dia cada um, cerca de metade da capacidade de oito a nove cortes por dia (RN06). O volume semanal de atendimentos não foi informado pelo responsável, por isso esse é um parâmetro do grupo, e o KPI G10 mostra essa ocupação. Assim:

| Tabela | Registros | Justificativa |
|---|---:|---|
| `AGENDAMENTO`, `AGENDAMENTO_SERVICO` | 500 | 2 profissionais × 5 atendimentos/dia × 50 dias de funcionamento (cerca de 50 por semana). |
| `AGENDAMENTO_EXTRA` | 83 | Cerca de um em cada seis atendimentos inclui sobrancelha, hidratação ou pigmentação. |
| `PAGAMENTO` | 519 | Uma cobrança por agendamento e 19 estornos de cancelamentos feitos com antecedência. |
| `AVALIACAO` | 140 | Cerca de um terço dos atendimentos concluídos recebe avaliação, com notas de 3 a 5. |
| `CLIENTE` | 45 | 32 clientes recorrentes atendidos no período e 13 cadastrados sem agendamento. |
| `PROFISSIONAL` | 3 | Dois ativos (duas cadeiras) e um inativo, mantido no histórico (RN08). |
| `SERVICO`, `SERVICO_EXTRA` | 7 e 3 | Catálogo de cortes, barba e combos, com um serviço promocional inativo. |
| `PRODUTO`, `FORNECEDOR`, `COMPRA`, `ITEM_COMPRA` | 12, 3, 3, 12 | Estoque inicial de revenda e insumos, comprado de três fornecedores. |
| `VENDA`, `ITEM_VENDA` | 31 | Cerca de três vendas de balcão por semana, mais uma venda ainda aberta. |
| `MOVIMENTO_CAIXA`, `MOVIMENTO_ESTOQUE` | 534 e 44 | Gerados pelas operações acima (entradas, estornos, baixas de contas, vendas e compras). |
| `CONTA_PAGAR` | 6 | Aluguel de três meses, compra de estoque, limpeza e energia. |
| Tabelas de apoio | poucas linhas | Calendário (9 regras), usuários (6), fechamentos (2), documentos fiscais (49) e log (3). |

**Cenários cobertos.** Atendimentos concluídos, cancelados com estorno, reservas expiradas sem pagamento e faltas; seis serviços diferentes, com e sem adicionais; pagamentos em Pix, crédito, débito e dinheiro; um produto abaixo do estoque mínimo; venda com desconto e venda sem cliente identificado; clientes sem agendamento; uma conta atrasada e outra a vencer; e um fechamento de caixa com diferença de R$ 12,50 no dinheiro. A consulta V01 do script mostra o volume carregado em cada tabela.

## 5. Repositório GitHub

O relatório técnico é este `README.md`, na raiz da branch `main`. Os demais artefatos do projeto são organizados assim:

| Artefato | Arquivo |
|---|---|
| Dicionário de Dados com atributos e restrições por coluna | [docs/dicionario-de-dados.html](docs/dicionario-de-dados.html) (para turma GTI, um `.md` separado do README) |
| DER conceitual | [diagramas/der-conceitual.png](diagramas/der-conceitual.png) |
| Modelo lógico | [diagramas/modelo-logico.png](diagramas/modelo-logico.png) |
| Levantamento da organização | [levantamento/levantamento.md](levantamento/levantamento.md) |
| Evidências do local e da entrevista | [levantamento/evidencias/](levantamento/evidencias/) (JPG ou PNG) |
| Script SQL completo (com consultas, auditorias e testes) | [docs/script.sql](docs/script.sql) |
| Massa de dados | [docs/massa-de-dados.sql](docs/massa-de-dados.sql) |
| Apresentação | [docs/slides.pptx](docs/slides.pptx) e [vídeo no YouTube](https://www.youtube.com/watch?v=BFF4zciVx5s) |

O histórico de commits registra o desenvolvimento ao longo do tempo e a contribuição dos integrantes com suas próprias contas do GitHub.

## 6. Uso de Inteligência Artificial

O grupo declarou uso de Gemini e DeepSeek na organização do README, nos requisitos e no apoio à modelagem. ChatGPT foi usado na consolidação desta documentação. A IA serviu para estruturar e revisar o material; não substitui a entrevista, a conferência dos scripts nem a validação das regras com a organização.

| Ferramenta/etapa | Motivação e prompt | Resultado e revisão |
|---|---|---|
| DeepSeek, conversão do script | Converter a versão PostgreSQL para MySQL sem alterar tabelas ou relacionamentos. Prompt usado: "Meu colega fez o banco da Barbearia The Family em PostgreSQL. Consegue converter o SQL para MySQL sem mudar as tabelas e os relacionamentos?" | A conversão foi usada como apoio ao script MySQL. O grupo executou e validou os arquivos no MySQL. |
| Gemini, revisão da documentação | Verificar pendências e coerência entre a documentação e o banco de dados. Prompt usado: "Analisa o README do projeto e me explica o que ainda falta fazer no trabalho da Barbearia The Family e se a documentação está coerente com o banco de dados." | A resposta serviu para revisar as pendências e a consistência da documentação. O grupo conferiu manualmente os arquivos antes de manter as alterações. |
| Claude, script MySQL e DER conceitual | Apoiar a leitura do modelo lógico, do repositório e a conversão para DER no brModelo, notação Peter Chen. Prompts usados: "Como está esse arquivo do modelo lógico do meu projeto?" e "Esse é o arquivo SQL https://github.com/gustavofjose/BarbeariaTheFamily do projeto. Leia o README, preciso fazer o MODELO DER no brModelo Peter Chen, por onde eu começo?" | A resposta foi usada como apoio para revisar o modelo e orientar a montagem do DER. O grupo executou e validou os arquivos no MySQL. A revisão manual conferiu a compatibilidade entre o script, os diagramas e o dicionário. |
| ChatGPT, consolidação do relatório | Integrar as informações já existentes no projeto, o dicionário e os artefatos finais em um README consistente. | O texto foi reestruturado. Regras sem confirmação foram marcadas como proposta ou pendência. |
| Claude (Claude Code), organização do script, consultas e massa de dados | O professor pediu que as consultas ficassem no mesmo arquivo do script e que cada uma indicasse o problema que resolve; a massa tinha um único serviço e nenhum adicional. Prompts usados: "Veja se está tudo OK com o projeto; a prioridade seria deixar 2 arquivos SQL juntando testes-e-consultas ao final do script" e "corrigir a massa". | O arquivo de testes foi incorporado ao `script.sql`, com cabeçalhos P/PN/RN em cada consulta. Foram criadas as consultas S01, S02, U01–U03, D01, D02, G06–G11 e A05–A07, e a massa passou a variar serviços, adicionais, formas de pagamento, notas e estornos. O script foi executado do zero no MySQL 8.0.46 sem erros, com auditorias em zero e testes T01–T05 em OK. O grupo conferiu os resultados antes de manter as alterações. |

As fontes utilizadas foram o levantamento do grupo, a foto feita no local e os dados de identificação da organização. O grupo deve registrar as respostas do responsável e conferir informações fiscais e sanitárias com profissionais competentes. Um risco do uso de IA é transformar uma prática comum em fato da barbearia; por isso, parâmetros como sinal, prazo de cancelamento e tolerância estão sinalizados como pendentes de confirmação. Na massa de dados, a IA gerou volumes coerentes com as regras do banco, mas os números (por exemplo, cinco atendimentos por profissional por dia) são parâmetros do grupo e não dados informados pela barbearia. Uma primeira versão da massa distribuía os serviços só pelo horário, de modo que um profissional nunca fazia barba; isso foi corrigido para variar também pelo dia.

## 7. Apresentação Corporativa Final

**Vídeo da apresentação:** [https://www.youtube.com/watch?v=BFF4zciVx5s](https://www.youtube.com/watch?v=BFF4zciVx5s)

**Slides:** [docs/slides.pptx](docs/slides.pptx)

O pitch de oito minutos apresenta, nesta ordem: problema de gestão da barbearia; solução proposta; modelo lógico; execução do SQL; consultas gerenciais e de auditoria; potencial de BI/IA; benefícios para a tomada de decisão. Os slides usam texto curto e apoio visual. Todos os integrantes participam da apresentação e da defesa do modelo.
