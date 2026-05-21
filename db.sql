CREATE EXTENSION IF NOT EXISTS "pgcrypto";
 

-- PERFIS

CREATE TABLE perfis (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome_completo   TEXT NOT NULL,
    papel           TEXT NOT NULL DEFAULT 'aluno'
                    CHECK (papel IN ('aluno', 'admin_escolar', 'admin_global')),
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

--Escolas
CREATE TABLE escolas (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome      TEXT NOT NULL,
    cnpj      TEXT NOT NULL UNIQUE,
    admin_id  UUID NOT NULL REFERENCES perfis(id),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

--Matriculas
CREATE TABLE matriculas (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id       UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    escola_id      UUID NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
    matriculado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
 
    UNIQUE (aluno_id, escola_id)
);
 
 --Questoes
 CREATE TABLE questoes (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_interno      SERIAL,
    enunciado           TEXT NOT NULL,
    alternativas        TEXT NOT NULL,
    alternativa_correta INT  NOT NULL CHECK (alternativa_correta BETWEEN 1 AND 5),
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT now()
);

--Sessões de simulado
CREATE TABLE sessoes_simulado (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aluno_id       UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    iniciado_em    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finalizado_em  TIMESTAMPTZ,
    status         TEXT NOT NULL DEFAULT 'em_andamento'
                   CHECK (status IN ('em_andamento', 'concluida')),
    total_questoes INT  NOT NULL DEFAULT 0,
    total_acertos  INT  NOT NULL DEFAULT 0
);