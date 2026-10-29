# Sistema de Gestão da Barbearia The Family Hair

## Equipe

| Integrante | RGM | Usuário GitHub |
|---|---:|---|
| Antonio Dantas da Silva Neto | 47788356 | AntonioDS |
| Arthur de Jesus Salviano Oliveira | 47764988 | arthurjso12-dev |
| Gustavo Frutuoso José | 47604565 | gustavofjose |
| Heitor Tureck de Oliveira | 47104503 | syndaflod |
| Lucas Ramon Bezerra Gomes | 47766263 | — |

## Identificação da organização
-<img src="fotoEntrevista.jpg" width="250" />
- **Nome fantasia:** The Family Hair
- **Razão social:** 61.946.399 William Loreilhe
- **CNPJ:** 61.946.399/0001-92
- **Endereço:** Rua Sonho Gaúcho, 352, Jardim São Nicolau, São Paulo — SP, CEP 03685-000
- **Telefone:** (11) 98520-6485
## 1. Relatório Técnico Final

Este projeto especifica a base de dados de gestão da Barbearia The Family Hair. O sistema organiza agenda e atendimento e reúne os registros de clientes, profissionais, serviços, pagamentos, vendas, compras, estoque e caixa. Os dados estruturados apoiam a operação diária e a análise gerencial.

### 1.1 Revisão do Modelo Conceitual

#### Caracterização da organização

A Barbearia The Family Hair é uma organização real do setor de beleza masculina, com atendimento de barbearia. A estrutura considerada no modelo possui duas cadeiras e cadastro de profissionais; o barbeiro Victor é citado no levantamento inicial. O sistema suporta múltiplos profissionais para que cada agenda e atendimento sejam associados ao responsável correto.

Os serviços considerados incluem corte, barba, combos e adicionais. A operação utiliza agendamento para organizar os atendimentos. O problema de gestão identificado é a confusão na marcação de horários, somada a cancelamentos e faltas de última hora, que podem deixar períodos sem atendimento.

O escopo abrange também cadastro de clientes, catálogo de serviços e adicionais, pagamentos, avaliações, venda de produtos, compras e fornecedores, estoque, contas a pagar, caixa, calendário, auditoria e registros de higiene. O modelo dá suporte aos dados da organização em conjunto, em vez de isolar somente a agenda.

#### Processos de negócio

Processos de negócio e fluxos operacionais: da reserva e atendimento à administração, auditoria e ciclo de vida dos dados.

**1. Cadastro e identificação do cliente.** No primeiro atendimento, registrar somente nome, telefone necessário para contato e, se desejado, e-mail; conferir os dados com o titular, explicar o uso operacional e não condicionar o serviço à aceitação de propaganda. Buscar duplicidade pelo telefone, permitir correção e registrar data de criação/atualização. Marketing requer opção separada, revogável e registrada.

**2. Escolha de serviço e extras.** O cliente escolhe um ou mais serviços ativos de `SERVICO` e adicionais opcionais de `SERVICO_EXTRA`. Gravar as escolhas em `AGENDAMENTO_SERVICO` e `AGENDAMENTO_EXTRA`, mostrar descrição, duração, preço unitário e total antes da confirmação. Um agendamento confirmado precisa de ao menos um serviço principal; FK sozinha não garante isso.

**3. Profissional, data e horário.** Oferecer profissionais ativos e consultar `REGRA_CALENDARIO` para os dias/horários semanais e exceções publicados pela barbearia (incluindo feriados abertos ou fechados). Validar que início e término caibam no expediente e verificar conflito por profissional com intervalos sobrepostos, inclusive em operações simultâneas. A premissa inicial é terça a sábado, 08:00–19:00, com domingo e segunda fechados.

**4. Pagamento durante o agendamento.** Antes de confirmar a reserva, apresentar total e política de cancelamento e cobrar/registrar o pagamento nesse mesmo fluxo: Pix, cartão de crédito, cartão de débito ou dinheiro. Pix/cartão só contam após confirmação do provedor/adquirente; dinheiro somente quando recebido no balcão. Criar `PAGAMENTO` para cada tentativa; confirmação só após valor total devido estar pago. Não guardar número completo do cartão, CVV, senha ou token. Reserva pendente segura o horário por no máximo 10 min (proposta configurável); após expirar, liberar a vaga e reconciliar callback tardio com o provedor antes de qualquer nova cobrança/estorno.

**5. Confirmação e lembretes.** Em uma transação, persistir agendamento, serviços/extras, preço contratado, pagamento confirmado e movimento financeiro. Só então mudar para Confirmado e emitir recibo/comprovante; o documento fiscal aplicável segue a rotina definida com a contabilidade. Enviar confirmação e lembretes de 24 h e 1 h pelos canais escolhidos, sem usar esses avisos para marketing.

**6. Chegada, tolerância e atendimento.** Registrar chegada/check-in. Política sugerida: tolerância de 10 minutos; o cliente deve avisar se estiver atrasado. Depois disso, atender apenas se a agenda permitir, podendo reduzir o serviço com concordância ou oferecer remarcação. Com mais de 15 minutos sem contato, pode-se marcar falta e liberar o horário. Comunicar a regra antes da reserva; não há padrão legal único para tolerância.

**7. Execução e higiene entre clientes.** Conferir serviço contratado, realizar atendimento e registrar conclusão. Entre clientes, remover resíduos e fazer limpeza/desinfecção adequada; instrumentos reutilizáveis que exijam esterilização devem seguir instruções do fabricante e normas sanitárias locais, com registro de etapa, responsável, horário e resultado. Materiais de uso único não são reprocessados.

**8. Cancelamento, remarcação e falta.** Registrar quem solicitou, data/hora, motivo opcional, antecedência, status anterior/novo e decisão sobre crédito/reembolso. Política sugerida: cancelamento/remarcação com 2 h ou mais permite uma remarcação ou reembolso; abaixo de 2 h, falta ou atraso além do limite, o valor pré-pago pode ser tratado conforme política de reserva previamente aceita e legislação aplicável. Não cobrar multa adicional automática; reincidência pode exigir confirmação manual da próxima reserva. Comunicar a decisão ao cliente e registrar o estorno/crédito, sem apagar o pagamento original.

**9. Venda de produtos no balcão.** Identificar produto, quantidade, preço, desconto autorizado e total; concluir venda em `VENDA`/`ITEM_VENDA`, receber por Pix, crédito, débito ou dinheiro e gerar saída de estoque na mesma transação. Cliente é opcional para venda de balcão. Nunca permitir saldo negativo sem ajuste autorizado e auditado.

**10. Compras e reposição de estoque.** Responsável cadastra fornecedor, registra pedido/compra, itens, quantidades e custos em `COMPRA`/`ITEM_COMPRA`, confere mercadoria e documento do fornecedor no recebimento e só então atualiza o estoque. Divergências, perdas, validade/lote quando pertinente e devoluções são registradas; não editar saldo sem trilha.

**11. Contas a pagar e caixa.** Lançar obrigações com fornecedor, origem, vencimento, valor e status; alertar vencimentos e registrar cada baixa. `MOVIMENTO_CAIXA` mantém entradas/saídas por origem e forma; abertura/fechamento registra saldo inicial, esperado, contado e diferença por dinheiro, Pix e cartões. Conferir relatórios do adquirente/banco, justificar divergências e impedir alteração de caixa já fechado sem estorno/auditoria.

**12. Documento fiscal.** Associar documentos emitidos às vendas/prestações e documentos recebidos às compras. O tipo de documento, incidência, emissão e prazo dependem do regime tributário, município e operação; validar com contador/Prefeitura/SEFAZ, conservar os arquivos pelo prazo fiscal aplicável e não substituir documento fiscal por recibo de pagamento.

**13. Relatórios e avaliação.** Fechar agenda e caixa por período, profissional e forma de pagamento; acompanhar ocupação, cancelamentos/faltas, vendas, margem, giro e estoque mínimo. Após atendimento concluído, permitir uma avaliação por agendamento, sem publicar comentário pessoal sem revisão e finalidade adequada.

**14. Gestão de acessos, auditoria e direitos.** Conceder acesso individual por função, desativar contas no desligamento, registrar alterações e consultas relevantes. Atender pedidos de titulares com verificação de identidade e registrar resposta; expurgar/anonimizar no prazo aprovado, salvo retenção legal ou exercício regular de direitos. Em incidente, conter, preservar evidências e avaliar comunicação conforme obrigação aplicável.

#### Requisitos funcionais

- **RF01 — Clientes:** cadastrar e atualizar nome, telefone e e-mail opcional; manter o status do cadastro e evitar duplicidade conforme a regra definida para telefone.
- **RF02 — Profissionais:** cadastrar profissionais e controlar sua situação ativa sem excluir atendimentos anteriores.
- **RF03 — Catálogo:** cadastrar serviços e adicionais com nome, descrição, duração, preço e situação ativa.
- **RF04 — Agendamentos:** registrar cliente, profissional, data, início, término, status e observação opcional; associar um ou mais serviços e zero ou mais adicionais.
- **RF05 — Disponibilidade:** consultar calendário e agenda, calcular a duração total e impedir sobreposição de horários do mesmo profissional.
- **RF06 — Pagamentos:** registrar tentativas, forma, valor, status, data/hora e relação com agendamento; manter estorno como operação referenciada ao pagamento original.
- **RF07 — Atendimento e avaliação:** atualizar o status do atendimento e aceitar avaliação somente após conclusão.
- **RF08 — Produtos e compras:** registrar fornecedores, compras, vendas e respectivos itens; atualizar o estoque após recebimento ou venda concluída.
- **RF09 — Financeiro:** registrar contas a pagar, movimentos de caixa e fechamento por forma de pagamento.
- **RF10 — Consultas:** produzir consultas gerenciais e de auditoria para agenda, cancelamentos, atendimentos, pagamentos, estoque e caixa.
- **RF11 — Auditoria:** registrar o usuário responsável por alterações relevantes de agenda, estoque e caixa.

#### Requisitos não funcionais

- **RNF01 — Privacidade:** limitar a coleta de dados pessoais ao necessário para cadastro, agendamento e atendimento.
- **RNF02 — Segurança:** controlar acesso por usuário e não armazenar dados completos de cartão, CVV, senhas ou credenciais.
- **RNF03 — Integridade:** aplicar PK, FK e restrições de domínio; usar transações nas confirmações de agendamento, pagamento, venda, compra e fechamento.
- **RNF04 — Desempenho:** a consulta de disponibilidade deve responder em menos de dois segundos nas condições previstas para a operação.
- **RNF05 — Usabilidade:** permitir consulta e atualização rápida da agenda durante os atendimentos.
- **RNF06 — Disponibilidade:** permitir solicitações de agendamento fora do horário de atendimento; a meta técnica de disponibilidade deve ser definida na implantação.

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

#### Restrições organizacionais, legais e de privacidade

| Código | Restrição | Aplicação no sistema |
|---|---|---|
| RN15 | Higienização/desinfecção entre atendimentos e esterilização quando aplicável. | Registrar procedimento e responsável de acordo com instruções do fabricante e normas sanitárias competentes; o sistema não define parâmetros técnicos de esterilização. |
| RN16 | Documentos fiscais, tributos e prazos de guarda dependem do enquadramento da organização. | Manter referências e status dos documentos; validar emissão e guarda com a contabilidade e autoridade competente. |
| RN17 | Dados pessoais precisam de finalidade, controle de acesso e período de retenção; marketing é separado e opcional. | Coletar o mínimo necessário, restringir acesso e manter procedimento de revisão/descarte. |

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
| `CLIENTE` — `AGENDAMENTO` | Cliente `(0,N)`; agendamento `(1,1)`. |
| `PROFISSIONAL` — `AGENDAMENTO` | Profissional `(0,N)`; agendamento `(1,1)`. |
| `AGENDAMENTO` — `SERVICO` | N:N por `AGENDAMENTO_SERVICO`; agendamento confirmado exige ao menos um serviço. |
| `AGENDAMENTO` — `SERVICO_EXTRA` | N:N por `AGENDAMENTO_EXTRA`; extras são opcionais. |
| `AGENDAMENTO` — `PAGAMENTO` | Agendamento `(0,N)`; cada tentativa pertence a um agendamento `(1,1)`. |
| `AGENDAMENTO` — `AVALIACAO` | Agendamento `(0,1)`; avaliação pertence a um agendamento concluído `(1,1)`. |
| `COMPRA` — `PRODUTO` | N:N por `ITEM_COMPRA`, com quantidade e custo praticado. |
| `VENDA` — `PRODUTO` | N:N por `ITEM_VENDA`, com quantidade e preço praticado. |

**DER conceitual:** [modelo_logico.png](modelo_logico.png). O diagrama representa entidades, atributos, identificadores, relacionamentos, entidades associativas e cardinalidades mínimas/máximas nos dois lados. Foi elaborado em [informar software utilizado].

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
| `CLIENTE` | `id_cliente` | — |
| `PROFISSIONAL` | `id_profissional` | — |
| `AGENDAMENTO` | `id_agendamento` | `id_cliente`, `id_profissional`, `id_regra_calendario` |
| `AGENDAMENTO_SERVICO` | `id_agendamento`, `id_servico` | `AGENDAMENTO`, `SERVICO` |
| `AGENDAMENTO_EXTRA` | `id_agendamento`, `id_extra` | `AGENDAMENTO`, `SERVICO_EXTRA` |
| `SERVICO` | `id_servico` | — |
| `SERVICO_EXTRA` | `id_extra` | — |
| `PAGAMENTO` | `id_pagamento` | `id_agendamento`, `id_pagamento_origem` (autorrelacionamento de estorno) |
| `AVALIACAO` | `id_avaliacao` | `id_agendamento` (único) |
| `USUARIO_SISTEMA` | `id_usuario` | — |
| `LOG_AUDITORIA` | `id_log` | `id_usuario` |
| `PRODUTO` | `id_produto` | — |
| `FORNECEDOR` | `id_fornecedor` | — |
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
| `REGRA_CALENDARIO` | `id_regra_calendario` | — |

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
- `NOT NULL`, `UNIQUE`, `CHECK` e `DEFAULT` documentam e implementam as regras operacionais RN01–RN18.
- Serviços, adicionais e profissionais são inativados em vez de excluídos, mantendo a integridade de operações passadas.

### 1.6 Proposta analítica para BI e IA

| Indicador | Cálculo e período | Tabelas | Consulta gerencial |
|---|---|---|---|
| Ocupação da agenda | Minutos reservados ÷ minutos disponíveis, por profissional e semana. | `AGENDAMENTO`, `PROFISSIONAL`, `REGRA_CALENDARIO`, itens de serviço. | `G01` |
| Cancelamentos e faltas | Reservas canceladas/faltas ÷ total de reservas, por mês. | `AGENDAMENTO` e histórico de status. | `G02` |
| Atendimentos realizados | Contagem de atendimentos concluídos por profissional e dia. | `AGENDAMENTO`, `PROFISSIONAL`. | `G03` |
| Estoque abaixo do mínimo | Produtos com saldo inferior ao mínimo na data da consulta. | `PRODUTO`, `MOVIMENTO_ESTOQUE`. | `G04` |
| Conciliação do caixa | Valor conferido menos valor esperado por forma e fechamento. | `MOVIMENTO_CAIXA`, `FECHAMENTO_CAIXA`, `FECHAMENTO_FORMA`. | `G05` |

As consultas de auditoria `A01`… verificam regras como conflito de horários (RN09), pagamento e confirmação (RN11/RN18), integridade de estoque (RN13) e imutabilidade do caixa fechado (RN14). Um painel pode apresentar ocupação, horários de pico, cancelamentos, atendimentos, estoque e caixa. Análises preditivas de faltas ou recomendação de horários são possibilidades futuras, condicionadas à qualidade e ao volume dos dados e à governança de privacidade.

## 2. Modelo Lógico Relacional

O modelo lógico é apresentado em [diagrama.png](diagrama.png), elaborado no brModelo. Ele contém tabelas, colunas e tipos, PK, FK e cardinalidades convertidas. As demais restrições de integridade estão no dicionário e no script SQL.

## 3. Script SQL Completo

O script MySQL do projeto fica em [`docs/script.sql`](docs/script.sql). Ele cria o banco e as tabelas, implementa PK/FK e restrições, carrega dados fictícios, demonstra consultas com `JOIN`, `UPDATE`, `DELETE`, consultas gerenciais `G01`–`G05` e auditorias `A01`… Cada consulta informa a pergunta respondida e a regra ou problema atendido.

## 4. Massa de Dados

A massa é fictícia e reproduz os processos modelados sem utilizar dados reais de clientes. A quantidade de registros representa o porte da operação: duas cadeiras, profissionais cadastrados, atendimentos, serviços, produtos e movimentações em períodos distintos.

Os cenários incluem reservas concluídas, canceladas e faltas; clientes sem agendamento recente; diferentes serviços e adicionais; formas de pagamento distintas; produtos abaixo do mínimo; compras recebidas; vendas concluídas; e fechamentos com diferença para demonstrar consultas de gestão e auditoria. O script inclui a carga da massa e a explicação do volume por tabela.

## 5. Repositório GitHub

O relatório técnico é este `README.md`, na raiz da branch `main`. Os demais artefatos do projeto são organizados assim:

| Artefato | Arquivo |
|---|---|
| Dicionário de Dados com atributos e restrições por coluna | `dicionario_de_dados.html` (para turma GTI, um `.md` separado do README) |
| DER conceitual | `modelo_logico.png` |
| Modelo lógico | `diagrama.png` |
| Levantamento da organização | `levantamento/levantamento.md` |
| Evidências do local e da entrevista | `levantamento/evidencias/` (JPG ou PNG) |
| Script SQL e massa | `docs/script.sql` |
| Apresentação | slides do pitch final |

O histórico de commits registra o desenvolvimento ao longo do tempo e a contribuição dos integrantes com suas próprias contas do GitHub.

## 6. Uso de Inteligência Artificial

O grupo declarou uso de Gemini e DeepSeek na organização do README, nos requisitos e no apoio à modelagem. ChatGPT foi usado na consolidação desta documentação.

| Ferramenta/etapa | Motivação e prompt | Resultado e revisão |
|---|---|---|
| Gemini e DeepSeek — documentação e modelagem | Organizar a documentação e propor requisitos/modelagem para o sistema de agendamento a partir das regras fornecidas para a barbearia. | A estrutura e as sugestões de modelagem foram revisadas pelo grupo. Sugestões com nomes, preços ou dados pessoais inventados foram descartadas. Registrar os prompts completos usados e as respostas efetivamente aproveitadas. |
| ChatGPT — consolidação do relatório | Integrar informações do projeto, dicionário e estrutura dos artefatos finais em um README consistente. | A estrutura foi consolidada; parâmetros de operação devem ser comparados com o levantamento e validados pelo responsável antes da implantação. A IA não comprova os processos reais nem substitui a validação da equipe. |

As fontes utilizadas para as regras operacionais são o levantamento da organização e o catálogo/processos informados pelo grupo. Informações legais, fiscais e sanitárias devem ser confirmadas com responsáveis competentes; sugestões da IA não são tratadas como confirmação desses requisitos.

## 7. Apresentação Corporativa Final

O pitch de oito minutos apresenta, nesta ordem: problema de gestão da barbearia; solução proposta; modelo lógico; execução do SQL; consultas gerenciais e de auditoria; potencial de BI/IA; benefícios para a tomada de decisão. Os slides usam texto curto e apoio visual. Todos os integrantes participam da apresentação e da defesa do modelo.
