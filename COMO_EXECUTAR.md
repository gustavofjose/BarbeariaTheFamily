# Como executar e popular o banco (MySQL)

São dois arquivos para **MySQL 8.0.16 ou superior**. A versão mínima é exigida porque só a partir dela o MySQL aplica as restrições `CHECK` do modelo. O banco usa InnoDB e `utf8mb4`.

- `docs/script.sql`: script completo. Cria o banco, as tabelas, as constraints e os gatilhos, carrega a massa de dados e executa os SELECT com JOIN, os UPDATE, os DELETE, as consultas gerenciais G01 a G11, as auditorias A01 a A07 e os testes T01 a T05.
- `docs/massa-de-dados.sql`: a mesma carga de dados, em arquivo separado, para recarregar os dados sem recriar o banco.

## Antes de começar

1. Instale o MySQL Server 8.0.16+ e o MySQL Workbench (ou use o cliente de linha de comando `mysql`).
2. Confirme que o serviço MySQL está iniciado.
3. Crie uma conexão no Workbench (ícone **+** ao lado de *MySQL Connections*):
   - **Hostname:** `127.0.0.1` (ou `localhost`); não coloque a porta neste campo.
   - **Port:** `3306` (ou a porta configurada na instalação).
   - **Username/password:** os definidos na instalação (normalmente `root`).
4. Use um usuário com privilégio para criar banco, tabelas, gatilhos (`TRIGGER`), procedimentos e eventos (`EVENT`). O `root` local resolve.

## Executar pelo MySQL Workbench

O `script.sql` cria o banco `barbearia_the_family` sozinho e já seleciona o banco com `USE`. Não é preciso criá-lo antes.

1. Conecte ao servidor e abra uma aba de consulta (**File > Open SQL Script**).
2. Abra `docs/script.sql` e execute o arquivo inteiro com o ícone do raio (**Execute**, `Ctrl+Shift+Enter`). Não use só o botão de executar a linha atual.
3. Espere terminar sem erros no painel *Output*. Cada consulta abre uma aba de resultado (*Result 1*, *Result 2*...) abaixo do editor, na ordem do arquivo: V01, S01, S02, U01 a U03, D01 e D02, G01 a G11, A01 a A07 e T01 a T05.

Para rodar só uma consulta de novo (por exemplo, na apresentação), selecione o bloco dela no editor e use **Execute** (`Ctrl+Shift+Enter`) apenas sobre a seleção. A consulta G09 usa `@data_referencia`; execute antes a linha `SET @data_referencia = '2026-11-11';`.

## Executar pela linha de comando (alternativa)

Na pasta do projeto:

```bash
mysql -u root -p --default-character-set=utf8mb4 -t < docs/script.sql
```

A opção `-t` formata os resultados em tabela. Para recarregar só os dados depois:

```bash
mysql -u root -p --default-character-set=utf8mb4 < docs/massa-de-dados.sql
```

## Regras de execução

- O `script.sql` cria as tabelas sem `IF NOT EXISTS`. Rodá-lo duas vezes dá erro de tabela já existente. Para recomeçar do zero, apague o banco e execute o script de novo:

```sql
DROP DATABASE barbearia_the_family;
```

Use isso apenas no banco do exercício. Não execute o `script.sql` em um servidor com dados que você queira preservar.
- A `massa-de-dados.sql` pode ser reexecutada, pois começa limpando as tabelas.
- Os testes T01 a T05 criam um procedimento temporário (`executar_testes_regras`), capturam os erros esperados e o removem no final. Não ficam registros inválidos no banco. Cada teste deve retornar `OK`.
- As auditorias A01 a A07 devem retornar **zero violações**.

## Eventos agendados

O script cria dois eventos: `ev_expirar_reservas` (libera reservas aguardando pagamento após o prazo) e `ev_marcar_contas_atrasadas`. Eles só rodam automaticamente com o agendador ligado:

```sql
SHOW VARIABLES LIKE 'event_scheduler';
SET GLOBAL event_scheduler = ON;  -- exige privilégio administrativo
```

Sem isso, as tabelas, os gatilhos e as consultas funcionam normalmente; apenas a expiração automática não é executada.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `Can't connect to MySQL server` | Serviço parado, porta errada ou porta digitada no campo de host | Inicie o serviço, confira a porta (3306) e deixe o host só como `127.0.0.1` ou `localhost` |
| Erro 1419 ao criar `TRIGGER` ou `PROCEDURE` (*you do not have the SUPER privilege and binary logging is enabled*) | Usuário sem privilégio com o log binário ligado | Execute como `root` ou, em ambiente de desenvolvimento, rode `SET GLOBAL log_bin_trust_function_creators = 1;` como administrador |
| Erro de sintaxe perto de `DELIMITER` | Arquivo executado por um cliente que não entende `DELIMITER` | Use o Workbench ou o cliente `mysql` |
| `Table ... already exists` | `script.sql` executado mais de uma vez | `DROP DATABASE barbearia_the_family;` e recomece |
| Restrições `CHECK` não bloqueiam nada | MySQL abaixo de 8.0.16 | Atualize para 8.0.16 ou superior (`SELECT VERSION();`) |
| Acentos quebrados | Conexão sem `utf8mb4` | Os scripts já usam `SET NAMES utf8mb4`; na linha de comando, mantenha `--default-character-set=utf8mb4` |

A massa de dados é fictícia e usa datas fixas, o que torna os resultados das consultas reproduzíveis.
