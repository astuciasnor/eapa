// Estilo Typst do livro EAPA (afeta apenas o PDF via Typst)
//
// Tabelas markdown SEM nenhuma linha (sem cabecalho e sem rodape).
// (As tabelas "Ocean"/flextable nao sao afetadas: o Quarto as renderiza
//  como imagem, nao como #table nativo.)

#set table(
  inset: 6pt,
  stroke: none,   // tabela sem nenhuma linha
)

// Cabecalho (rotulos das colunas) em negrito
#show table.cell.where(y: 0): set text(weight: "bold")

// Blocos de codigo e de saida (raw em bloco) com fonte menor,
// para caber saidas largas (ex.: a tabela do teste t) numa linha so.
#show raw.where(block: true): set text(size: 7.5pt)

// Menos espaco abaixo dos titulos (titulo do capitulo -> texto)
#show heading: set block(above: 1.0em, below: 0.55em)

// Legendas de figura: texto justificado (em vez de centralizado),
// fica melhor para as legendas mais longas do livro.
#show figure.caption: set align(left)
#show figure.caption: set par(justify: true)

// Justifica a lista de referencias. O Quarto usa a bibliografia NATIVA do Typst
// (#bibliography), que ignora o #set par global; por isso a regra entra "dentro"
// do elemento bibliography.
#show bibliography: set par(justify: true)
// Hifenizacao na bibliografia: deixa o Typst quebrar palavras longas para
// fechar as linhas do meio na margem (resolve linhas curtas como a do periodico).
#show bibliography: set text(hyphenate: true)
