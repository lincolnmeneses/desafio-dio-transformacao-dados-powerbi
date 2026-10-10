-- Junção de cada colaborador com o nome do respectivo gerente (autojunção da tabela employee).
-- LEFT JOIN para manter o colaborador sem gerente (James Borg, topo da hierarquia).
use azure_company;

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

-- Quantidade de colaboradores por gerente
SELECT CONCAT(m.Fname, ' ', m.Lname) AS gerente, COUNT(*) AS qtd_colaboradores
FROM employee e
JOIN employee m ON e.Super_ssn = m.Ssn
GROUP BY m.Ssn, m.Fname, m.Lname
ORDER BY qtd_colaboradores DESC;
