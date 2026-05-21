Table perfis {
  id          uuid        [pk, default: `uuid_generate_v4()`, note: "Mesmo ID do auth.users"]
  nome_completo text      [not null]
  papel       text        [not null, default: "aluno", note: "aluno | admin_escolar | admin_global"]
  criado_em   timestamptz [not null, default: `now()`]
}
 
Table escolas {
  id          uuid        [pk, default: `uuid_generate_v4()`]
  nome        text        [not null]
  cnpj        text        [not null, unique]
  admin_id    uuid        [not null, ref: > perfis.id]
  criado_em   timestamptz [not null, default: `now()`]
}
 
Table matriculas {
  id          uuid        [pk, default: `uuid_generate_v4()`]
  aluno_id    uuid        [not null, ref: > perfis.id]
  escola_id   uuid        [not null, ref: > escolas.id]
  matriculado_em timestamptz [not null, default: `now()`]
 
  indexes {
    (aluno_id, escola_id) [unique, name: "uq_matricula"]
  }
}
 
Table questoes {
  id           uuid  [pk, default: `uuid_generate_v4()`]
  numero_interno serial
  enunciado    jsonb [not null, note: "Texto, fórmulas, imagens — formato flexível"]
  alternativas jsonb [not null, note: "Alternativas em formato flexível"]
  alternativa_correta int [not null, note: "1 a 5"]
  criado_em    timestamptz [not null, default: `now()`]
}
 
Table sessoes_simulado {
  id              uuid  [pk, default: `uuid_generate_v4()`]
  aluno_id        uuid  [not null, ref: > perfis.id]
  iniciado_em     timestamptz [not null, default: `now()`]
  finalizado_em   timestamptz
  status          text  [not null, default: "em_andamento", note: "em_andamento | concluida"]
  total_questoes  int   [not null, default: 0]
  total_acertos   int   [not null, default: 0]
}
 
Table respostas_alunos {
  id               uuid    [pk, default: `uuid_generate_v4()`]
  sessao_id        uuid    [not null, ref: > sessoes_simulado.id]
  questao_id       uuid    [not null, ref: > questoes.id]
  alternativa_escolhida int [not null]
  acertou          boolean [not null]
  respondido_em    timestamptz [not null, default: `now()`]
 
  indexes {
    (sessao_id, questao_id) [unique, name: "uq_resposta_por_sessao"]
  }
}