# Roteiro revisado: slides 12 a 17

Substitui as partes 4 e 5 do roteiro (4:48 a 8:00). Os números abaixo saem do `docs/script.sql` atual, executado do zero. Mudanças em relação ao roteiro anterior:

- a execução agora é **um arquivo só** (`script.sql`);
- entram **duas gravações de tela** do MySQL Workbench, porque o pitch exige "SQL rodando" e "demonstração de consultas";
- o slide 17 passa a mostrar os **benefícios para a tomada de decisão**, item obrigatório que faltava.

Ritmo de referência: cerca de 2,5 palavras por segundo. As falas cabem no tempo indicado.

Correções que valem para as partes 1 a 3 (sem mudar o tempo):

- **Slide 6, "Na tela":** "menos de 2 segundos" é desempenho (RNF04), não disponibilidade.
- **Slide 3, complemento:** não falar no vídeo que "as respostas do responsável não foram registradas na hora".

---

## Parte 4 (Integrante 4): Implementação em MySQL e massa de dados · 4:48 a 6:24

### Slide 12 · MySQL 8.0.16+ (4:48 a 5:24)

**Na tela:** 25 tabelas (NOT NULL, UNIQUE, CHECK, DEFAULT), 35 gatilhos, 2 eventos agendados, "1 script executa tudo do zero".

**Fala:** Obrigado. Implementamos o banco em MySQL 8.0.16 ou superior, porque é a partir dessa versão que as restrições CHECK valem. Um único arquivo, o script.sql, cria o banco e as 25 tabelas com NOT NULL, UNIQUE, DEFAULT e CHECK. Também cria 35 gatilhos, que fazem o próprio banco recusar o que viola as regras, como horário sobreposto ou alteração de movimento já fechado. Por fim, cria 2 eventos agendados: um libera reservas não pagas e o outro marca contas atrasadas.

### Demonstração 1 · SQL rodando (5:24 a 5:54) — gravação de tela

**Na tela:** MySQL Workbench. Abrir `docs/script.sql`, clicar no raio (Execute) e mostrar o painel *Output* terminando sem erros. Depois abrir a aba de resultado da **V01** (volume por tabela).

**Fala:** Aqui está o script rodando do zero no Workbench. Ele segue a ordem pedida: criação das tabelas, constraints, carga dos dados, consultas com JOIN, UPDATE, DELETE, consultas gerenciais, auditorias e testes. O painel de saída termina sem nenhum erro. E esta primeira consulta, a V01, mostra quantos registros cada tabela recebeu.

### Slide 13 · Massa de dados fictícia (5:54 a 6:24)

**Na tela:** 500 agendamentos em 10 semanas · 6 serviços e 83 adicionais · 519 pagamentos (Pix, crédito, débito, dinheiro, 19 estornos) · 140 avaliações · 31 vendas · "datas fixas: mesmos resultados em qualquer máquina".

**Fala:** A massa é fictícia e cobre dez semanas. São dois profissionais com cinco atendimentos por dia cada, de terça a sábado, o que dá 500 agendamentos. Há seis serviços diferentes, 83 adicionais, pagamentos nas quatro formas e 19 estornos. Colocamos de propósito faltas, cancelamentos, um produto zerado, uma conta atrasada e uma diferença no caixa, para que as consultas tenham o que mostrar.

---

## Parte 5 (Integrante 5): Consultas, testes, BI/IA e conclusão · 6:24 a 8:00

### Slide 14 + Demonstração 2 · Consultas gerenciais (6:24 a 7:00) — gravação de tela

**Na tela:** primeiro o slide com a tabela P1, P2 e P3 → consultas. Depois a gravação no Workbench mostrando as abas **G08**, **G04** e **G05**.

**Fala:** Obrigado. Cada dor tem uma consulta que responde a ela, e cada consulta traz no código o problema que resolve. Para a P1, a G08 mostra a taxa de faltas e cancelamentos: cerca de 16% ao mês, acima da meta de 10%. Para a P2, a G03 e a G11 mostram receita por profissional e ticket médio, de 57 reais. Para a P3, a G04 aponta a pomada matte zerada e a G05 mostra 12,50 faltando no dinheiro do caixa.

### Slide 15 · Auditorias e testes (7:00 a 7:20)

**Na tela:** A01 a A07 com "0 violações" e T01 a T05 com "OK" (pode ser print do Workbench).

**Fala:** Sete auditorias, de A01 a A07, procuram dados que quebram as regras, como horário sobreposto, estorno maior que o pagamento e estoque negativo. Todas retornam zero. E nos testes T01 a T05 tentamos gravar dados inválidos de propósito. O banco recusou as cinco tentativas.

### Slide 16 · BI e inteligência artificial (7:20 a 7:36)

**Na tela:** painel com os KPIs G08, G10, G11, G04 e G05; "previsão de faltas" e declaração de uso de IA.

**Fala:** Esses KPIs têm fórmula, período e meta, e alimentam diretamente um painel de BI. Com mais histórico, o mesmo dado de faltas permite prever quem tende a faltar. Declaramos no README o uso de Gemini, DeepSeek, ChatGPT e Claude, sempre com conferência manual.

### Slide 17 · Benefícios para a decisão e conclusão (7:36 a 8:00)

**Na tela:** três decisões: "16% de faltas → lembrete e confirmação", "pomada zerada → repor 6 unidades", "aluguel atrasado 6 dias → priorizar pagamento". Embaixo: "Agenda sem conflito. Histórico único. Estoque e caixa conferidos. Obrigado."

**Fala:** Na prática, o dono decide com números: se as faltas passam de 10%, reforça o lembrete e a confirmação; se um produto zera, sabe o que repor; e vê as contas atrasadas antes de virarem multa. Saímos de três dores e chegamos a uma agenda sem conflito, um histórico único e estoque e caixa conferidos. Muito obrigado!

---

## Como gravar as demonstrações

1. Antes de gravar, apague o banco (`DROP DATABASE barbearia_the_family;`) para mostrar a execução do zero.
2. Abra `docs/script.sql` no Workbench e clique no raio (Execute, `Ctrl+Shift+Enter`). A execução leva alguns segundos por causa dos 500 agendamentos; se precisar, corte a espera na edição.
3. As abas de resultado seguem a ordem do arquivo: V01, S01, S02, U01–U03, D01–D02, G01–G11, A01–A07, T01–T05.
4. Para mostrar uma consulta isolada, selecione o bloco dela e execute só a seleção. Para a G09, execute antes `SET @data_referencia = '2026-11-11';`.
