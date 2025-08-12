-- ============================================================================
-- PROJETO DE LIMPEZA DE DADOS - LAYOFFS DATASET
-- ============================================================================
-- Objetivo: Limpar e padronizar dados de demissões corporativas
-- Banco: PostgreSQL
-- Autor: [Seu Nome]
-- Data: [Data do Projeto]
-- ============================================================================

-- FASE 0: EXPLORAÇÃO INICIAL DOS DADOS
-- ============================================================================

-- Testando a estrutura e conteúdo da tabela original
SELECT * FROM layoffs LIMIT 5;

-- FASE 1: PREPARAÇÃO DO AMBIENTE
-- ============================================================================

-- Criando uma cópia exata da tabela original para trabalhar com segurança
-- Boa prática: Nunca trabalhar diretamente nos dados originais
-- Isso permite recuperação em caso de erro durante o processo de limpeza
CREATE TABLE layoff_stagging (LIKE layoffs INCLUDING ALL);
INSERT INTO layoff_stagging SELECT * FROM layoffs;

-- Verificando se a cópia foi criada corretamente
SELECT * FROM layoff_stagging LIMIT 5;

-- Instalando extensão para remoção de acentos e caracteres especiais
-- Necessária para padronização de campos de texto
CREATE EXTENSION IF NOT EXISTS unaccent;

-- FASE 2: IDENTIFICAÇÃO E REMOÇÃO DE DUPLICATAS
-- ============================================================================

-- Testando a identificação de duplicatas com ROW_NUMBER()
-- Particiona os dados por campos chave para identificar registros idênticos
SELECT *, ROW_NUMBER() OVER(
PARTITION BY company, industry,total_laid_off, percentage_laid_off,date) AS row_num
FROM layoff_stagging;

-- Removendo duplicatas usando CTE (Common Table Expression)
-- Estratégia: Manter apenas a primeira ocorrência (row_num = 1)
-- Usa ctid (identificador físico da linha) para remoção precisa
WITH duplicadas_cte AS (
    SELECT ctid,
           ROW_NUMBER() OVER (
               PARTITION BY company,
                            "location",
                            industry,
                            total_laid_off,
                            percentage_laid_off,
                            "date",
                            stage,
                            country,
                            funds_raised_millions
           ) AS row_num
    FROM layoff_stagging
)
DELETE FROM layoff_stagging
WHERE ctid IN (
    SELECT ctid
    FROM duplicadas_cte
    WHERE row_num > 1
);

-- Verificação específica: testando empresa Casper após remoção de duplicatas
SELECT * FROM layoff_stagging WHERE company = 'Casper';

-- FASE 3: PADRONIZAÇÃO DOS DADOS
-- ============================================================================

-- 3.1 PADRONIZAÇÃO DA COLUNA COMPANY
-- ----------------------------------------------------------------------------

-- Analisando espaços em branco desnecessários nos nomes das empresas
SELECT company,TRIM(company) 
FROM layoff_stagging ORDER BY company;

-- Removendo espaços em branco no início e fim dos nomes das empresas
UPDATE layoff_stagging
SET company = TRIM(company);

-- 3.2 PADRONIZAÇÃO DA COLUNA INDUSTRY
-- ----------------------------------------------------------------------------

-- Analisando valores únicos na coluna industry para identificar inconsistências
SELECT DISTINCT industry
FROM layoff_stagging
ORDER BY 1;

-- Identificando variações do setor Crypto
SELECT * 
FROM layoff_stagging
WHERE industry LIKE 'Crypto%';

-- Unificando todas as variações de Crypto em um único valor padronizado
-- Ex: 'CryptoCurrency', 'Crypto Currency' → 'Crypto'
UPDATE layoff_stagging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- 3.3 PADRONIZAÇÃO DA COLUNA LOCATION
-- ----------------------------------------------------------------------------

-- Analisando valores únicos na coluna location
SELECT DISTINCT "location"
FROM layoff_stagging
ORDER BY 1;

-- Testando a limpeza de caracteres especiais e acentos
-- Função unaccent(): remove acentos
-- Regex '[^\w\s]': remove tudo exceto letras, números e espaços
SELECT DISTINCT
    "location",unaccent(regexp_replace(location, '[^\w\s]', '', 'g')) AS location_clean
FROM layoff_stagging
ORDER BY location_clean;

-- Aplicando a padronização na coluna location
UPDATE layoff_stagging 
SET location = unaccent(regexp_replace(location, '[^\w\s]', '', 'g'));

-- 3.4 PADRONIZAÇÃO DA COLUNA COUNTRY
-- ----------------------------------------------------------------------------

-- Analisando valores únicos na coluna country
SELECT DISTINCT country
FROM layoff_stagging
ORDER BY 1;

-- Testando a limpeza de países com a mesma estratégia
SELECT DISTINCT
    country,unaccent(regexp_replace(country, '[^\w\s]', '', 'g')) AS country_clean
FROM layoff_stagging
ORDER BY country_clean;

-- Aplicando a padronização na coluna country
UPDATE layoff_stagging 
SET country = unaccent(regexp_replace(country, '[^\w\s]', '', 'g'));

-- 3.5 PADRONIZAÇÃO DA COLUNA DATE
-- ----------------------------------------------------------------------------

-- Analisando o formato atual das datas (provavelmente texto)
SELECT date FROM layoff_stagging;

-- Removendo registros com formato de data inválido
-- Regex: ^\d{1,2}/\d{1,2}/\d{4}$ valida formato MM/DD/YYYY ou M/D/YYYY
DELETE FROM layoff_stagging
WHERE date !~ '^\d{1,2}/\d{1,2}/\d{4}$';

-- Comando duplicado removido (estava repetido no código original)
DELETE FROM layoff_stagging
WHERE date !~ '^\d{1,2}/\d{1,2}/\d{4}$';

-- Testando a conversão de string para DATE
SELECT
  date,
  TO_DATE(date, 'MM/DD/YYYY') AS formatted_date
FROM layoff_stagging;

-- Convertendo valores de data de texto para formato DATE
UPDATE layoff_stagging
SET date = TO_DATE(date, 'MM/DD/YYYY');

-- Alterando o tipo da coluna de TEXT para DATE
ALTER TABLE layoff_stagging
ALTER COLUMN "date" TYPE DATE USING date::DATE;

-- Verificando se a alteração de tipo foi bem-sucedida
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'layoff_stagging' AND column_name = 'date';

-- FASE 4: TRATAMENTO DE VALORES NULOS E VAZIOS
-- ============================================================================

-- 4.1 TRATAMENTO INTELIGENTE DE NULLS NA COLUNA INDUSTRY
-- ----------------------------------------------------------------------------

-- Identificando registros com industry nula ou vazia
SELECT * FROM layoff_stagging
WHERE industry ISNULL or industry = ' ';

-- Análise exploratória: verificando empresas específicas
-- para entender padrões de dados nulos
SELECT * FROM layoff_stagging WHERE company = 'Airbnb';
SELECT * FROM layoff_stagging WHERE company = 'Juul';
SELECT * FROM layoff_stagging WHERE company = 'Carvana';

-- Identificando oportunidades de preenchimento inteligente
-- Busca registros da mesma empresa com industry preenchida
SELECT * 
FROM layoff_stagging ls1
JOIN layoff_stagging ls2
	ON ls1.company = ls2.company
	AND ls1.location = ls2.location
WHERE (ls1.industry ISNULL OR ls1.industry = '')
AND ls2.industry IS NOT NULL;

-- Preenchimento inteligente: atualiza industry nula usando dados
-- de outros registros da mesma empresa
UPDATE layoff_stagging ls1
SET industry = ls2.industry
FROM layoff_stagging ls2
WHERE ls1.company = ls2.company
  AND (ls1.industry IS NULL OR ls1.industry = '')
  AND ls2.industry IS NOT NULL;

-- FASE 5: CONVERSÃO DE TIPOS DE DADOS E LIMPEZA FINAL
-- ============================================================================

-- 5.1 CONVERSÃO DA COLUNA TOTAL_LAID_OFF
-- ----------------------------------------------------------------------------

-- Identificando valores 'NULL' como string (problema comum em imports)
SELECT total_laid_off FROM layoff_stagging WHERE total_laid_off = 'NULL';

-- Convertendo string 'NULL' para NULL real
UPDATE layoff_stagging
SET total_laid_off = NULL
WHERE total_laid_off = 'NULL';

-- Alterando tipo da coluna de TEXT para INTEGER
ALTER TABLE layoff_stagging
ALTER COLUMN total_laid_off TYPE INTEGER USING total_laid_off::integer;

-- 5.2 CONVERSÃO DA COLUNA PERCENTAGE_LAID_OFF
-- ----------------------------------------------------------------------------

-- Mesmo processo para percentage_laid_off
SELECT percentage_laid_off FROM layoff_stagging WHERE percentage_laid_off = 'NULL';

-- Convertendo string 'NULL' para NULL real
UPDATE layoff_stagging
SET percentage_laid_off = NULL
WHERE percentage_laid_off = 'NULL';

-- Alterando tipo da coluna de TEXT para FLOAT
ALTER TABLE layoff_stagging
ALTER COLUMN percentage_laid_off TYPE FLOAT USING percentage_laid_off::float;

-- 5.3 REMOÇÃO DE REGISTROS SEM VALOR ANALÍTICO
-- ----------------------------------------------------------------------------

-- Identificando registros sem informações de demissão
-- Estes registros não têm valor para análise
SELECT *
FROM layoff_stagging
WHERE total_laid_off ISNULL
AND percentage_laid_off ISNULL;

-- Removendo registros que não possuem dados de demissão
-- Decisão de negócio: registros sem total_laid_off E percentage_laid_off
-- não contribuem para análises sobre demissões
DELETE
FROM layoff_stagging
WHERE total_laid_off ISNULL
AND percentage_laid_off ISNULL;