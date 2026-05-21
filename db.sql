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

-- TRIGGER: validar que admin da escola tem papel correto
CREATE OR REPLACE FUNCTION verificar_papel_admin_escola()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM perfis
        WHERE id = NEW.admin_id AND papel = 'admin_escolar'
    ) THEN
        RAISE EXCEPTION 'O admin da escola deve ter o papel admin_escolar';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_admin_escola
    BEFORE INSERT OR UPDATE ON escolas
    FOR EACH ROW EXECUTE FUNCTION verificar_papel_admin_escola();


-- TRIGGER: atualizar contadores da sessão a cada resposta
CREATE OR REPLACE FUNCTION atualizar_contadores_sessao()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE sessoes_simulado
        SET
            total_questoes = total_questoes + 1,
            total_acertos  = total_acertos + (CASE WHEN NEW.acertou THEN 1 ELSE 0 END)
        WHERE id = NEW.sessao_id;
 
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE sessoes_simulado
        SET
            total_acertos = total_acertos
                          - (CASE WHEN OLD.acertou THEN 1 ELSE 0 END)
                          + (CASE WHEN NEW.acertou THEN 1 ELSE 0 END)
        WHERE id = NEW.sessao_id;
 
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE sessoes_simulado
        SET
            total_questoes = total_questoes - 1,
            total_acertos  = total_acertos - (CASE WHEN OLD.acertou THEN 1 ELSE 0 END)
        WHERE id = OLD.sessao_id;
    END IF;
 
    RETURN NULL;
END;
$$;
 
CREATE TRIGGER on_resposta_inserida
    AFTER INSERT OR UPDATE OR DELETE ON respostas_alunos
    FOR EACH ROW EXECUTE FUNCTION atualizar_contadores_sessao();

-- ROW LEVEL SECURITY
ALTER TABLE perfis           ENABLE ROW LEVEL SECURITY;
ALTER TABLE escolas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE matriculas       ENABLE ROW LEVEL SECURITY;
ALTER TABLE questoes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessoes_simulado ENABLE ROW LEVEL SECURITY;
ALTER TABLE respostas_alunos ENABLE ROW LEVEL SECURITY;


-- Função auxiliar: papel do usuário logado
CREATE OR REPLACE FUNCTION papel_atual()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT papel FROM perfis WHERE id = auth.uid();
$$;

--Perfis
CREATE POLICY aluno_proprio_perfil ON perfis
    FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());
 
CREATE POLICY admin_escolar_ver_alunos ON perfis
    FOR SELECT USING (
        papel_atual() = 'admin_escolar'
        AND EXISTS (
            SELECT 1 FROM matriculas m
            JOIN escolas e ON e.id = m.escola_id
            WHERE m.aluno_id = perfis.id AND e.admin_id = auth.uid()
        )
    );

CREATE POLICY admin_global_perfis ON perfis
FOR ALL
USING    (papel_atual() = 'admin_global')
WITH CHECK (papel_atual() = 'admin_global');

--Escolas
CREATE POLICY admin_escolar_propria_escola ON escolas
    FOR ALL USING (admin_id = auth.uid()) WITH CHECK (admin_id = auth.uid());
 
CREATE POLICY admin_global_escolas ON escolas
    FOR ALL USING (papel_atual() = 'admin_global');

--Matrículas
CREATE POLICY aluno_proprias_matriculas ON matriculas
    FOR SELECT USING (aluno_id = auth.uid());
 
CREATE POLICY admin_escolar_matriculas ON matriculas
    FOR ALL
    USING (EXISTS (
        SELECT 1 FROM escolas WHERE id = matriculas.escola_id AND admin_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM escolas WHERE id = matriculas.escola_id AND admin_id = auth.uid()
    ));
 
CREATE POLICY admin_global_matriculas ON matriculas
    FOR ALL USING (papel_atual() = 'admin_global');

--Questões_Leitura
CREATE POLICY autenticado_ler_questoes ON questoes
    FOR SELECT USING (auth.uid() IS NOT NULL);
 
CREATE POLICY admin_global_questoes ON questoes
    FOR ALL USING (papel_atual() = 'admin_global');