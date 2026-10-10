# 🔄 Processando e Transformando Dados com Power BI

Desafio de projeto da trilha **Primeiros Passos em Power BI** (DIO): integrar a base **company** (MySQL na Azure) ao Power BI e aplicar as etapas de coleta, verificação e transformação de dados no **Power Query**.

Base de dados fornecida pela especialista: [julianazanelatto/power_bi_analyst](https://github.com/julianazanelatto/power_bi_analyst) (`Módulo 3/Desafio de Projeto`).

---

## 🧭 Etapas do projeto

1. **Instância MySQL na Azure.** *Azure Database for MySQL – Servidor Flexível*, com uma regra de firewall liberando o IP local.
2. **Criação do banco** `azure_company` com os scripts da pasta [`sql/`](sql):
   - [`01_criar_banco_azure_company.sql`](sql/01_criar_banco_azure_company.sql): tabelas e restrições
   - [`02_inserir_dados.sql`](sql/02_inserir_dados.sql): carga dos dados, já com as correções descritas abaixo
   - [`03_colaborador_e_gerente.sql`](sql/03_colaborador_e_gerente.sql): consultas de colaborador × gerente
3. **Integração com o Power BI** pelo conector MySQL (veja [Como trocar a fonte para o MySQL na Azure](#️-como-trocar-a-fonte-para-o-mysql-na-azure)).
4. **Verificação e transformação dos dados** no Power Query, descritas a seguir.

> **Fonte usada neste repositório:** a base company foi exportada em CSV na pasta [`dados/`](dados), com o mesmo conteúdo dos scripts. O Power BI lê esses arquivos, então o projeto abre e atualiza em qualquer computador, sem depender de um servidor na Azure ligado. Todas as transformações partem das consultas `*_raw`, e para ligar no MySQL basta trocar a etapa de fonte dessas consultas.

---

## 🐞 Problemas encontrados na base (scripts SQL)

| Problema | Correção |
| --- | --- |
| O script de inserção usa `use company_constraints;`, mas o banco criado se chama `azure_company` | Trocado para `use azure_company;` |
| `employee.Super_ssn` referencia o próprio `employee`, e alguns gerentes são inseridos depois dos subordinados, o que gera erro de chave estrangeira | `SET FOREIGN_KEY_CHECKS = 0` durante a carga, religado ao final |
| As consultas de exemplo do script usam aspas tipográficas (`‘John’`), que não são válidas em SQL | Removidas do script de carga |
| O nome da tabela de departamentos está escrito `departament` | Mantido como no original, para não quebrar as chaves estrangeiras |

---

## 🛠️ Transformações aplicadas (Power Query)

As consultas `*_raw` são de **preparação**, com a carga desabilitada: elas leem a fonte e promovem os cabeçalhos. As tabelas finais partem delas.

| Diretriz do desafio | O que foi feito | Resultado |
| --- | --- | --- |
| Verificar cabeçalhos e tipos de dados | Cabeçalhos promovidos e tipos definidos em todas as tabelas. Textos, datas e números foram convertidos com a cultura `en-US`, porque os dados usam ponto decimal | Todos os campos tipados |
| Valores monetários como "double preciso" | `Salary` foi convertido para **Número decimal fixo** (`Currency.Type`), o tipo preciso para dinheiro | Coluna `Salário` |
| Verificar nulos e analisar a remoção | Valores vazios foram convertidos para `null` antes da tipagem. O único nulo é `Super_ssn` de **James Borg** | Nenhuma linha removida: o nulo tem significado (veja abaixo) |
| Colaboradores sem gerente | `Super_ssn` nulo indica o topo da hierarquia. **James Borg** é o diretor e foi identificado como "Sem gerente (diretor)" | 1 colaborador sem gerente |
| Departamentos sem gerente | Coluna `Possui Gerente`. Se faltasse um gerente, a lacuna seria preenchida com "Gerente a definir" | Os 3 departamentos têm gerente |
| Número de horas dos projetos | `works_on` agrupada por projeto (soma de horas e quantidade de colaboradores) e mesclada em `Projetos` | 275 horas no total. James Borg tem 0 h em *Reorganization* |
| Separar colunas complexas | `Address` (`731-Fondren-Houston-TX`) foi separada em **Número, Rua, Cidade e Estado**. A rua pode ter hífen (`975-Fire-Oak-Humble-TX`), então a divisão usa o primeiro e os dois últimos pedaços | 4 colunas novas |
| Mesclar `employee` e `departament` | Mescla com base em `employee`, por **junção externa esquerda** (*Left Outer*), para manter todos os colaboradores mesmo que algum não tivesse departamento | Coluna `Departamento` em `Colaboradores` |
| Eliminar colunas desnecessárias | `Minit`, `Address`, `Dept_create_date` e as colunas auxiliares foram removidas | Tabelas enxutas |
| Colaborador × nome do gerente | **Autojunção** de `employee` (`Super_ssn` = `Ssn`) pela mescla do Power BI. A versão em SQL também está em [`sql/03_colaborador_e_gerente.sql`](sql/03_colaborador_e_gerente.sql) | Coluna `Gerente` |
| Mesclar Nome e Sobrenome | `Fname` + `Lname` foram mescladas em `Nome Completo` | — |
| Mesclar departamento e localização | `dept_locations` mesclada com `departament`, e criada a coluna `Departamento-Local`, com um índice como chave | 5 combinações únicas |
| Agrupar colaboradores por gerente | Tabela `Colaboradores_por_Gerente` (Agrupar por) | Franklin Wong: 3, James Borg: 2, Jennifer Wallace: 2 |

### Query SQL usada na junção colaborador × gerente

```sql
SELECT
    e.Ssn                              AS ssn_colaborador,
    CONCAT(e.Fname, ' ', e.Lname)      AS colaborador,
    d.Dname                            AS departamento,
    e.Super_ssn                        AS ssn_gerente,
    COALESCE(CONCAT(m.Fname, ' ', m.Lname), 'Sem gerente (diretor)') AS gerente
FROM employee e
LEFT JOIN employee m    ON e.Super_ssn = m.Ssn
LEFT JOIN departament d ON e.Dno = d.Dnumber
ORDER BY gerente, colaborador;
```

### ❓ Por que usar *mesclar* e não *acrescentar* (atribuir)?

- **Mesclar** junta tabelas **lado a lado**, ligando as linhas por uma chave em comum. `departament` e `dept_locations` têm colunas diferentes e se relacionam pela chave `Dnumber`: para cada local é preciso buscar o nome do departamento correspondente. Isso é uma junção (*join*), ou seja, mesclar.
- **Acrescentar** empilha **linhas** de tabelas com a **mesma estrutura** (como juntar vendas de janeiro e de fevereiro). As duas tabelas não têm as mesmas colunas e não representam o mesmo tipo de registro. Empilhar geraria linhas incompletas, sem relacionar departamento e local.

Por isso, para criar a combinação departamento-local, só faz sentido **mesclar**.

---

## 🧱 Modelo resultante

| Tabela | Conteúdo |
| --- | --- |
| `Colaboradores` | Colaborador, endereço separado, salário, departamento e gerente |
| `Departamentos` | Departamento, gerente e data de início do gerente |
| `Departamento_Local` | Combinações únicas departamento-local (base para o modelo estrela) |
| `Projetos` | Projeto, local, departamento, total de horas e quantidade de colaboradores |
| `Trabalha_Em` | Horas de cada colaborador em cada projeto |
| `Dependentes` | Dependentes, com o parentesco traduzido (Filho, Filha, Cônjuge) |
| `Colaboradores_por_Gerente` | Agrupamento da quantidade de subordinados por gerente |
| `Medidas` | Medidas DAX (totais de colaboradores, projetos, horas e folha salarial) |

Relacionamentos: `Departamentos` → `Colaboradores` e `Departamento_Local`; `Colaboradores` → `Trabalha_Em` e `Dependentes`; `Projetos` → `Trabalha_Em`.

O relatório tem uma página **Visão Geral** para conferir os dados transformados: cartões, tabela de colaboradores com gerente, colaboradores por gerente, horas por projeto e departamento-local.

---

## ☁️ Como trocar a fonte para o MySQL na Azure

1. Instale o [MySQL Connector/NET](https://dev.mysql.com/downloads/connector/net/), exigido pelo conector MySQL do Power BI.
2. No Power BI, abra **Transformar dados** e, em cada consulta `*_raw`, troque a etapa `Fonte` por:

```powerquery
Fonte = MySQL.Database("SEU-SERVIDOR.mysql.database.azure.com", "azure_company", [ReturnSingleDatabase = true]),
CabecalhosPromovidos = Fonte{[Schema = "azure_company", Item = "employee"]}[Data]
```

(substitua `employee` pelo nome da tabela de cada consulta). Nenhuma outra etapa precisa mudar.

## ▶️ Como abrir

1. Abra `TransformacaoDados.pbip` no Power BI Desktop.
2. Clique em **Página Inicial → Atualizar**.
3. Se o repositório estiver em outra pasta, ajuste o parâmetro **PastaDados** em **Transformar dados → Editar parâmetros**. O caminho precisa terminar com `\`.

## 📁 Estrutura

```
├── dados/                              # base company exportada em CSV
├── sql/                                # scripts para criar e popular o MySQL na Azure
├── TransformacaoDados.pbip             # abre o projeto no Power BI Desktop
├── TransformacaoDados.Report/          # relatório
└── TransformacaoDados.SemanticModel/   # modelo em TMDL (consultas Power Query, tabelas, medidas)
```

## 🛠️ Tecnologias
- Azure Database for MySQL (Servidor Flexível)
- MySQL / SQL
- Power BI Desktop (Power Query e DAX)
- Git e GitHub
