// Estilo Typst do livro EAPA (afeta apenas o PDF via Typst)
//
// Tabelas markdown no estilo booktabs com linhas PRETAS:
//  - uma linha ACIMA do cabecalho;
//  - uma linha ABAIXO do cabecalho;
//  - uma linha no RODAPE da tabela.
// (As tabelas "Ocean"/flextable nao sao afetadas: o Quarto as renderiza
//  como imagem, nao como #table nativo.)

#set table(
  inset: 6pt,
  stroke: (x, y) => (
    top: if y == 0 { 0.9pt + black },     // acima do cabecalho
    bottom: if y == 0 { 0.6pt + black },  // abaixo do cabecalho
  ),
)

// Linha no rodape: caixa que abraca a largura da tabela, com borda inferior.
#show table: it => box(it, stroke: (bottom: 0.9pt + black))

// Menos espaco abaixo dos titulos (titulo do capitulo -> texto)
#show heading: set block(above: 1.0em, below: 0.55em)

// Legendas de figura: texto justificado (em vez de centralizado),
// fica melhor para as legendas mais longas do livro.
#show figure.caption: set align(left)
#show figure.caption: set par(justify: true)
