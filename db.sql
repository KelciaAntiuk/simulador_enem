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
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome      TEXT NOT NULL,
    cnpj      TEXT NOT NULL UNIQUE,
    admin_id  UUID NOT NULL REFERENCES perfis(id),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

--Matriculas
CREATE TABLE matriculas (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aluno_id       UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    escola_id      UUID NOT NULL REFERENCES escolas(id) ON DELETE CASCADE,
    matriculado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
 
    UNIQUE (aluno_id, escola_id)
);
 
 --Questoes
 CREATE TABLE questoes (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_interno      SERIAL,
    enunciado           JSONB NOT NULL,
    alternativas        JSONB NOT NULL,
    alternativa_correta INT  NOT NULL CHECK (alternativa_correta BETWEEN 1 AND 5),
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT now()
);

--Sessões de simulado
CREATE TABLE sessoes_simulado (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aluno_id       UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    iniciado_em    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finalizado_em  TIMESTAMPTZ,
    status         TEXT NOT NULL DEFAULT 'em_andamento'
                   CHECK (status IN ('em_andamento', 'concluida')),
    total_questoes INT  NOT NULL DEFAULT 0,
    total_acertos  INT  NOT NULL DEFAULT 0
);

-- RESPOSTAS DOS ALUNOS
CREATE TABLE respostas_alunos (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sessao_id             UUID    NOT NULL REFERENCES sessoes_simulado(id) ON DELETE CASCADE,
    questao_id            UUID    NOT NULL REFERENCES questoes(id) ON DELETE CASCADE,
    alternativa_escolhida INT     NOT NULL,
    acertou               BOOLEAN NOT NULL,
    respondido_em         TIMESTAMPTZ NOT NULL DEFAULT now(),
 
    UNIQUE (sessao_id, questao_id)
);
 
-- ÍNDICES
CREATE INDEX ON matriculas(aluno_id);
CREATE INDEX ON matriculas(escola_id);
CREATE INDEX ON sessoes_simulado(aluno_id);
CREATE INDEX ON respostas_alunos(sessao_id);
CREATE INDEX ON escolas(admin_id);
 
-- Cria o perfil de forma automática ao criar um usuário
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO perfis (id, nome_completo, papel)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nome_completo', 'Novo Usuário'),
        COALESCE(NEW.raw_user_meta_data->>'papel', 'aluno')
    );
    RETURN NEW;
END;
$$;
 
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();