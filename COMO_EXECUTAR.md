# Como executar e popular o banco (PostgreSQL)

Os arquivos `docs/script.sql`, `docs/massa-de-dados.sql` e `docs/testes-e-consultas.sql` formam a sequência para PostgreSQL 15 ou superior.

## Antes de começar

Instale/abra PostgreSQL e pgAdmin 4. O PostgreSQL precisa estar iniciado. Na janela de registro do servidor mostrada na captura, preencha:

- **Host name/address:** `localhost` (ou `127.0.0.1`); não coloque `5432` aqui.
- **Port:** `5432` (ou a porta configurada na instalação).
- **Maintenance database:** `postgres`.
- **Username/password:** os definidos na instalação do PostgreSQL.

O erro da captura ocorre porque `5432` foi informado como nome do host. Se `localhost` também falhar, confirme se o serviço PostgreSQL está iniciado e se a porta é mesmo 5432.

## Criar o banco e executar

1. No pgAdmin, conecte ao servidor e clique com o botão direito em **Databases > Create > Database**.
2. Nomeie o banco como `barbearia_faculdade` e salve.
3. Selecione esse banco; abra **Tools > Query Tool**.
4. Abra `docs/script.sql` no Query Tool e execute (ícone ▶ ou F5). Espere a mensagem de sucesso.
5. Sem trocar de banco, abra e execute `docs/massa-de-dados.sql`. Isso insere a massa fictícia.
6. Abra e execute `docs/testes-e-consultas.sql`. Ele apresenta volumes, consultas de exemplo, auditorias e testes. As demonstrações de UPDATE/DELETE e testes de bloqueio usam transações/ROLLBACK.
7. Para confirmar que carregou, execute `SELECT count(*) FROM barbearia.cliente;` e `SELECT count(*) FROM barbearia.agendamento;`.

Execute cada arquivo uma vez, nesta ordem, num banco vazio. Para recomeçar, apague e recrie somente o banco de exercício no pgAdmin e repita os passos. Não execute `docs/script.sql` em um banco que contenha dados que queira preservar.

## Correções e limites

- O domínio de `registro_higienizacao.resultado` foi alinhado ao dicionário: `Concluido`, `Reprovado`, `Refeito`.
- O arquivo de estrutura cria o schema `barbearia`. Os arquivos de população e consultas selecionam esse schema.
- Use apenas os três arquivos PostgreSQL acima. Versões anteriores e alternativas foram mantidas em `docs/historico/` apenas para consulta e não fazem parte do fluxo de execução.
- O relatório identificou que a estrutura principal `script.sql` não aplica no banco as regras RN04 (expediente) e RN11 (pagamento/serviço na confirmação); os testes as marcam como informativas. Não interprete os testes informativos como bloqueios aprovados.
- No modelo lógico, ajustes de estoque não têm sinal explícito e a view não os soma. A auditoria/consulta de saldo também não os contabiliza; valide a convenção com o professor antes de usar saldo como valor contábil.

A massa de dados é fictícia e tem datas fixas de setembro a novembro de 2026 para produzir resultados reproduzíveis.
