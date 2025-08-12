# Projeto de Limpeza de Dados - Demissões em Massa (Layoffs)

## Visão Geral do Projeto

Este projeto demonstra técnicas avançadas de limpeza de dados utilizando PostgreSQL em um dataset de demissões em massa de empresas. O objetivo é transformar dados brutos em informações estruturadas e confiáveis para análises posteriores.

## Objetivos

**Objetivo Principal**: Limpar e padronizar dados de demissões corporativas para análise

**Habilidades Técnicas Demonstradas**: 
- Manipulação avançada de dados em PostgreSQL
- Identificação e remoção de duplicatas
- Padronização de campos de texto
- Tratamento de valores nulos e inconsistentes
- Conversão de tipos de dados

## Dataset Utilizado

**Fonte**: Dados de demissões em massa de empresas  

**Estrutura dos Dados**:
- `company`: Nome da empresa
- `location`: Localização
- `industry`: Setor da indústria
- `total_laid_off`: Total de funcionários demitidos
- `percentage_laid_off`: Percentual de demissões
- `date`: Data da demissão
- `stage`: Estágio da empresa
- `country`: País
- `funds_raised_millions`: Fundos levantados (em milhões)

## Metodologia de Limpeza

### 1. Preparação e Backup dos Dados

```sql
-- Criação de tabela de staging para preservar dados originais
CREATE TABLE layoff_stagging (LIKE layoffs INCLUDING ALL);
INSERT INTO layoff_stagging SELECT * FROM layoffs;

-- Instalação de extensão para remoção de acentos
CREATE EXTENSION IF NOT EXISTS unaccent;
```

**Justificativa**: Criação de uma cópia dos dados originais como medida de segurança, permitindo recuperação em caso de erro. A extensão `unaccent` facilita a padronização de texto removendo acentos e caracteres especiais.

### 2. Identificação e Remoção de Duplicatas

```sql
WITH duplicadas_cte AS (
    SELECT ctid,
           ROW_NUMBER() OVER (
               PARTITION BY company, "location", industry, 
                          total_laid_off, percentage_laid_off, "date",
                          stage, country, funds_raised_millions
           ) AS row_num
    FROM layoff_stagging
)
DELETE FROM layoff_stagging
WHERE ctid IN (
    SELECT ctid FROM duplicadas_cte WHERE row_num > 1
);
```

**Técnicas Aplicadas**:
- **Window Function ROW_NUMBER()** para enumerar registros duplicados
- **Common Table Expression (CTE)** para estruturar a lógica de identificação
- **PARTITION BY** considerando todas as colunas para identificar registros completamente idênticos
- Uso do `ctid` (identificador físico da linha) para remoção precisa

### 3. Padronização de Campos de Texto

#### 3.1 Padronização da Coluna Company
```sql
UPDATE layoff_stagging SET company = TRIM(company);
```
Remoção de espaços em branco no início e fim dos nomes das empresas.

#### 3.2 Padronização da Coluna Industry
```sql
UPDATE layoff_stagging 
SET industry = 'Crypto' 
WHERE industry LIKE 'Crypto%';
```
Unificação de variações do setor de criptomoedas (ex: 'CryptoCurrency', 'Crypto Currency') em um único valor padronizado.

#### 3.3 Normalização de Location e Country
```sql
-- Para localização
UPDATE layoff_stagging 
SET location = unaccent(regexp_replace(location, '[^\w\s]', '', 'g'));

-- Para país
UPDATE layoff_stagging 
SET country = unaccent(regexp_replace(country, '[^\w\s]', '', 'g'));
```
Aplicação de expressão regular para remover caracteres especiais e uso da função `unaccent()` para normalizar acentos.

### 4. Conversão de Tipos de Dados

#### 4.1 Tratamento de Datas
```sql
-- Remoção de registros com formato de data inválido
DELETE FROM layoff_stagging WHERE date !~ '^\d{1,2}/\d{1,2}/\d{4}$';

-- Conversão para tipo DATE
UPDATE layoff_stagging SET date = TO_DATE(date, 'MM/DD/YYYY');
ALTER TABLE layoff_stagging ALTER COLUMN "date" TYPE DATE USING date::DATE;
```

#### 4.2 Conversão de Campos Numéricos
```sql
-- Total de demissões
UPDATE layoff_stagging SET total_laid_off = NULL WHERE total_laid_off = 'NULL';
ALTER TABLE layoff_stagging ALTER COLUMN total_laid_off TYPE INTEGER USING total_laid_off::integer;

-- Percentual de demissões
UPDATE layoff_stagging SET percentage_laid_off = NULL WHERE percentage_laid_off = 'NULL';
ALTER TABLE layoff_stagging ALTER COLUMN percentage_laid_off TYPE FLOAT USING percentage_laid_off::float;
```

### 5. Tratamento Inteligente de Valores Nulos

#### 5.1 Preenchimento Baseado em Contexto
```sql
UPDATE layoff_stagging ls1
SET industry = ls2.industry
FROM layoff_stagging ls2
WHERE ls1.company = ls2.company
  AND (ls1.industry IS NULL OR ls1.industry = '')
  AND ls2.industry IS NOT NULL;
```
Preenchimento automático de setores industriais nulos utilizando informações de outros registros da mesma empresa.

#### 5.2 Remoção de Registros Sem Valor Analítico
```sql
DELETE FROM layoff_stagging
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;
```
Exclusão de registros que não possuem informações sobre demissões, tornando-os irrelevantes para análise.

## Resultados Obtidos

### Estado Inicial dos Dados:
- Presença de registros duplicados
- Inconsistências na formatação de texto
- Valores nulos representados como strings 'NULL'
- Datas armazenadas como texto
- Caracteres especiais e acentuação inconsistente

### Estado Final dos Dados:
- Zero duplicatas no dataset
- Padronização completa de campos de texto
- Tipos de dados apropriados (INTEGER, FLOAT, DATE)
- Tratamento adequado de valores nulos
- Consistência para análises subsequentes

## Técnicas e Tecnologias Utilizadas

### Funções PostgreSQL:
- **TRIM()**: Limpeza de espaços em branco
- **LIKE/REGEXP**: Correspondência de padrões
- **REGEXP_REPLACE()**: Substituição usando expressões regulares
- **UNACCENT()**: Normalização de caracteres especiais
- **TO_DATE()**: Conversão de strings para datas
- **ROW_NUMBER() OVER()**: Funções de janela para numeração
- **Common Table Expressions (CTE)**: Estruturação de consultas complexas

### Conceitos de Qualidade de Dados:
- **Completeness**: Identificação e tratamento de lacunas
- **Consistency**: Padronização de formatos e valores
- **Uniqueness**: Eliminação de duplicatas
- **Validity**: Validação de tipos e formatos
- **Accuracy**: Correção de inconsistências

## Boas Práticas Implementadas

1. **Preservação de Dados Originais**: Utilização de tabela staging
2. **Validação Incremental**: Testes com consultas limitadas
3. **Documentação Técnica**: Comentários explicativos no código
4. **Análise Exploratória**: Verificação de casos específicos
5. **Conversões Seguras**: Uso de cláusulas USING para mudanças de tipo

## Impacto e Aplicabilidade

Este projeto de limpeza de dados resulta em um dataset confiável para:
- Análises exploratórias sobre tendências de demissões
- Desenvolvimento de dashboards executivos
- Modelagem preditiva de riscos corporativos
- Estudos setoriais e geográficos

## Competências Demonstradas

O projeto evidencia proficiência em:
- **SQL Avançado**: Uso de window functions, CTEs e expressões regulares
- **Pensamento Analítico**: Identificação sistemática de problemas nos dados
- **Metodologia Estruturada**: Processo organizado de limpeza
- **Atenção a Detalhes**: Tratamento específico de casos excepcionais
- **Melhores Práticas**: Backup, documentação e validação contínua
