// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
// Capa de pagina inteira, inserida ANTES da pagina de rosto padrao (page 1).
#page(margin: 0pt)[
  #image("/images/capa-livro-eapa.png", width: 100%, height: 100%, fit: "cover")
]
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
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 2.5cm,y: 2.5cm,),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Estatística Aplicada à Pesca e Aquicultura com R],
  author: "Evaldo Martins da Silva",
  date: "2026-02-04",
  lang: "pt",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Prefácio]
<prefácio>
Há uma distância conhecida entre dominar a teoria estatística e conseguir aplicá-la a dados reais. Nas ciências pesqueiras e aquícolas, ela se acentua: falta material didático em português que ligue, de forma aplicada, os fundamentos da estatística aos problemas concretos de quem trabalha com a pesca e a aquicultura. Este livro nasce para encurtar essa distância, oferecendo a estudantes, docentes e técnicos um caminho prático (da pergunta de pesquisa ao resultado interpretado), apoiado na linguagem R.

Mais do que uma obra isolada, este livro é a face escrita de um ecossistema de ensino. As análises que ele apresenta nascem na #strong[CatalyseR], uma interface visual que conduz o usuário "do mouse ao código": a análise é feita apontando e clicando e, ao final, o usuário leva consigo o script R que a reproduz. Os dados que ilustram cada método vêm do pacote #strong[EAPADados], que reúne conjuntos reais da pesca e da aquicultura, sobretudo amazônica. Livro, interface e pacote foram pensados para andar juntos --- o que se lê aqui é exatamente o que a interface executa e o que o pacote fornece.

A obra percorre os temas essenciais da estatística aplicada (da análise exploratória aos testes de hipóteses, da regressão à análise de variância), sempre com exemplos contextualizados e código reprodutível. A esses fundamentos somam-se alguns temas mais avançados, mas de uso corrente na pesquisa, como a análise multivariada, a regressão não linear e a confecção de mapas em R. A primeira edição foi mantida deliberadamente enxuta, concentrada nas análises já consolidadas, de modo a servir como um guia confiável e completo naquilo a que se propõe, deixando os demais temas mais avançados para edições futuras.

Um cuidado especial foi dado ao #strong[planejamento da pesquisa]. Antes de qualquer cálculo, é o desenho do estudo --- como amostrar uma população ou como organizar um experimento --- que decide quais análises serão possíveis e válidas; planejar a coleta é, na prática, escolher antecipadamente o teste. Por isso, logo após os fundamentos de ambientação, o planejamento abre uma unidade própria --- dedicada a preparar e conhecer os dados antes de analisá-los --- num capítulo que ensina a planejar tanto a observação (amostragem aleatória simples, estratificada e sistemática) quanto a experimentação (os delineamentos clássicos, do inteiramente casualizado às parcelas subdivididas), espelhando o módulo "Planejando sua Pesquisa" da CatalyseR. É um capítulo de fundamentos, mas dos mais importantes do livro: dele depende a qualidade de tudo o que vem depois.

Recomenda-se ler este livro com o R aberto. Cada capítulo foi escrito para ser acompanhado na prática: instale o pacote de dados, execute os exemplos, gere os gráficos e produza os relatórios. É percorrendo esse caminho, e repetindo-o, que a fluência se constrói.

#heading(level: 2, numbering: none)[Agradecimentos]
<agradecimentos>
Aos estudantes de graduação e pós-graduação da Universidade Federal do Pará, cuja participação ao longo dos anos foi essencial para o aprimoramento do ensino de estatística aqui consolidado.

Aos professores da UFPA que gentilmente cederam scripts e resultados de pesquisa, adaptados e incluídos como dados de apoio nas análises deste material.

À Editora da UFPA, pela valiosa ajuda na editoração deste livro e pelo cuidado com a qualidade do acabamento.

#part[Unidade I · Do mouse ao código]
= Introdução
<introdução>
Aprender a analisar dados em R costuma esbarrar em três obstáculos --- e nenhum deles é a estatística em si.

O primeiro é #strong[o código que assusta]. Quem abre o R pela primeira vez encontra um cursor piscando, à espera de instruções numa sintaxe desconhecida. A folha em branco intimida, e a primeira mensagem de erro (quase sempre por uma vírgula ou um parêntese) desanima antes mesmo de a análise começar. Muita gente que entende perfeitamente um teste de hipóteses trava na hora de pedir esse teste ao computador.

O segundo é #strong[a fragmentação dos recursos]. O material existe, mas espalhado: um tutorial num blog, um vídeo em inglês, um pacote documentado de um jeito, um exemplo num fórum. Reunir tudo isso numa análise coerente, do dado bruto ao gráfico final, costuma dar mais trabalho do que a análise propriamente dita.

O terceiro são #strong[os exemplos genéricos]. Os conjuntos de dados clássicos do R --- flores de íris, carros dos anos 1970 --- dizem pouco a quem estuda peixes, tanques e capturas. Aprende-se a técnica, mas não se enxerga onde ela encaixa no próprio trabalho. A ponte entre "como se faz" e "como eu faço com os meus dados" fica por conta do leitor.

== Um ecossistema, não um livro solto
<um-ecossistema-não-um-livro-solto>
Este livro responde aos três obstáculos de uma vez, porque não vem sozinho. Ele é uma das três peças de um mesmo ecossistema de ensino, pensadas para se apoiarem mutuamente (#ref(<fig-ecossistema>, supplement: [Figura])).

#figure([
#box(image("capitulos\\capitulo01/../../images/ecossistema-eapa.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
O ecossistema EAPA. As análises nascem na CatalyseR, que conduz o usuário do mouse ao código; o pacote EAPADados fornece os dados reais da pesca e da aquicultura para a interface e para o livro; e este livro documenta e ensina exatamente as mesmas análises. Uma única definição de cada análise, três formas de chegar a ela.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-ecossistema>


A #strong[CatalyseR] é uma interface visual (uma IDE) que enfrenta o primeiro obstáculo de frente: o usuário realiza a análise apontando e clicando, e a interface, ao final, entrega o #strong[script R] que reproduz tudo, além de um relatório pronto. É o que chamamos de #emph[do mouse ao código]: em vez de começar pela folha em branco, começa-se pelo resultado e caminha-se, com segurança, até o código que o gerou.

O pacote #strong[EAPADados] ataca o terceiro obstáculo. Em vez de flores e carros, ele traz conjuntos de dados reais da pesca e da aquicultura, com forte presença amazônica: biometrias, capturas, ensaios de ração, experimentos de cultivo. Os mesmos dados aparecem na interface, no livro e nos exercícios, instalados com um comando e acessíveis a qualquer momento.

E #strong[este livro] resolve o segundo obstáculo, reunindo num só lugar o que costuma estar disperso. Cada capítulo documenta uma análise do ecossistema do começo ao fim (a pergunta, a teoria essencial, o código, a interpretação e o relato), espelhando exatamente o que a CatalyseR executa. A regra que costura tudo é simples: existe #strong[uma única definição] de cada análise; a interface a executa, o livro a ensina e o pacote fornece os dados. Nada de versões que divergem entre si.

== O que esta primeira edição cobre
<o-que-esta-primeira-edição-cobre>
A primeira edição foi mantida enxuta de propósito. Em vez de tentar cobrir tudo superficialmente, ela se concentra nas análises já consolidadas no ecossistema e as apresenta com cuidado: a estatística descritiva e a análise exploratória, os testes #emph[t] (uma amostra, amostras independentes e pareadas), a regressão linear e a análise de variância (ANOVA). São as fundações sobre as quais quase todo o restante se constrói. A elas somam-se alguns temas mais avançados, porém de uso corrente no dia a dia da pesquisa: a #strong[análise multivariada], a #strong[regressão não linear] e a #strong[confecção de mapas] em R. Outros assuntos (como as séries temporais) ficam registrados como próximos passos para as edições seguintes.

== Para quem é, e o que esperar
<para-quem-é-e-o-que-esperar>
O livro fala a estudantes, técnicos e pesquisadores das ciências agrárias e biológicas (com destaque para a engenharia de pesca e a aquicultura), mas serve a qualquer pessoa que precise analisar dados e queira fazê-lo de forma reprodutível. Não se exige experiência prévia em programação: a abordagem #emph[do mouse ao código] foi desenhada justamente para quem está começando. Um conhecimento mínimo do R e do RStudio ajuda, e é exatamente o que os próximos dois capítulos oferecem, ao preparar o ambiente de trabalho e a organização de um projeto de análise.

== Como o livro está organizado
<como-o-livro-está-organizado>
Cada capítulo segue um mesmo percurso, para que você saiba sempre onde está: parte de uma situação concreta da pesca ou da aquicultura, apresenta os dados (sempre do EAPADados), constrói a intuição do método antes da fórmula, executa a análise no R e na CatalyseR, interpreta os resultados e fecha com um relato em linguagem natural e alguns exercícios em "Para praticar". A identidade visual é constante (a paleta Ocean Gradient nas tabelas e figuras), e os blocos de código são executáveis: você pode reproduzi-los exatamente como aparecem.

Os dados usados ao longo do livro vêm do pacote #NormalTok("EAPADados");, que se instala diretamente do GitHub:

#block[
#Skylighting(([#CommentTok("# instale o remotes uma vez, se ainda não tiver:");],
[#CommentTok("# install.packages(\"remotes\")");],
[],
[#NormalTok("remotes");#SpecialCharTok("::");#FunctionTok("install_github");#NormalTok("(");#StringTok("\"astuciasnor/EAPADados\"");#NormalTok(")");],
[],
[#FunctionTok("library");#NormalTok("(EAPADados)");],));
]
A partir daí, qualquer conjunto de dados do livro fica a um #NormalTok("data()"); de distância: #NormalTok("data(isoproteica_bagre)");, por exemplo, traz o experimento de rações que abre o capítulo de ANOVA. A teoria de cada método é mantida no mínimo necessário, com as referências indicadas para quem quiser se aprofundar. O foco, do início ao fim, é prático: usar o R com confiança e interpretar o que ele devolve.#NormalTok("data()"); de distância: #NormalTok("data(isoproteica_bagre)");, por exemplo, traz o experimento de rações que abre o capítulo de ANOVA. A teoria de cada método é mantida no mínimo necessário, com as referên

= Criação do Ambiente Computacional
<criação-do-ambiente-computacional>
Ou: como montar a sua bancada de análise uma vez --- e nunca mais brigar com instalação

\
#block[
#callout(
body: 
[
Você sentou para fazer uma análise simples --- comparar o peso de peixes de dois cultivos --- e, antes de qualquer estatística, perdeu a tarde com mensagens de erro vermelhas, pacote que não instala, "Rtools não encontrado". Quando o ambiente finalmente funcionou, a vontade de analisar já tinha ido embora. A boa notícia: isso se resolve #strong[uma vez]. Depois, a bancada está pronta e você só pensa nos dados.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Neste livro, a estatística começa no #strong[mouse] (na IDE CatalyseR) e termina no #strong[código], dentro do R. Para que essa ponte funcione, precisamos de uma bancada bem montada. Este capítulo monta essa bancada no Windows, peça por peça, e deixa tudo testado. Não é a parte glamourosa, mas é a que evita dor de cabeça em todos os capítulos seguintes.

== As quatro peças (e o que cada uma faz)
<as-quatro-peças-e-o-que-cada-uma-faz>
Pense numa oficina. Você não usa uma ferramenta só; usa um conjunto que conversa entre si. Nossa oficina de análise tem quatro peças:

O #strong[R] é o #strong[motor]: a linguagem que faz as contas, ajusta os modelos e desenha os gráficos. O #strong[RStudio] é o #strong[painel de controle]: a tela confortável de onde você dirige o motor, vê os dados, os gráficos e os resultados lado a lado. O #strong[Rtools] é a #strong[caixa de ferramentas de fábrica] do Windows: alguns pacotes do R chegam "em peças" e precisam ser montados (compilados) na sua máquina; sem o Rtools, eles não montam. E o #strong[Quarto] é a #strong[gráfica]: transforma a sua análise (texto + código + resultados) em um relatório bonito, em PDF, Word ou página web.

#quote(block: true)[
#strong[Por que o Rtools só no Windows?] No macOS e no Linux a "caixa de ferramentas" de compilação já costuma vir com o sistema. No Windows, ela é instalada à parte; por isso este capítulo dá atenção especial a ela.
]

== Instalando, na ordem certa
<instalando-na-ordem-certa>
A ordem importa: o Rtools precisa #strong[casar] com a versão do R. Instale assim:

+ #strong[R]: baixe a versão mais recente em #link("https://cran.r-project.org")[cran.r-project.org] (Windows → #emph[base] → #emph[Download R for Windows]). Anote a versão (ex.: 4.x).
+ #strong[RStudio]: baixe o #emph[RStudio Desktop] (gratuito) em #link("https://posit.co/download/rstudio-desktop")[posit.co/download/rstudio-desktop]. Ele encontra o R automaticamente.
+ #strong[Rtools]: baixe a versão de Rtools #strong[correspondente à do seu R] em #link("https://cran.r-project.org/bin/windows/Rtools/")[cran.r-project.org/bin/windows/Rtools]. Aceite as opções padrão do instalador.
+ #strong[Quarto]: baixe em #link("https://quarto.org/docs/get-started/")[quarto.org/docs/get-started]. O RStudio recente já vem com Quarto embutido, mas instalar a versão oficial garante o motor mais novo.

Feche e reabra o RStudio depois de instalar o Rtools: assim ele "enxerga" a caixa de ferramentas nova.

#block[
#callout(
body: 
[
Duas precauções evitam a maioria das dores de cabeça com permissões no Windows.

Primeiro, #strong[instale o R numa pasta gravável]. No caminho padrão (#NormalTok("C:\\Program Files\\R\\...");), a pasta da biblioteca de pacotes fica protegida pelo sistema, e o #NormalTok("install.packages()"); acaba caindo numa "biblioteca pessoal" escondida --- ou falhando com erros de permissão (#NormalTok("'lib = ...' is not writable");). A solução mais tranquila é criar uma pasta simples, como #strong[#NormalTok("C:\\R");], e apontar o instalador do R para ela (no instalador, troque o diretório de destino para #NormalTok("C:\\R\\R-4.x.x");). Assim a sua biblioteca fica sob seu controle, sem pedir privilégios a cada novo pacote.

Segundo, #strong[instale as quatro peças como administrador] (clique com o botão direito no instalador → #emph[Executar como administrador]): o #strong[R], o #strong[RStudio], o #strong[Rtools] e o #strong[Quarto]. Isso garante que os atalhos, as variáveis de ambiente e o registro do Windows fiquem corretos para todos os programas se encontrarem.

Se, mesmo assim, a pasta #NormalTok("...\\R\\R-4.x.x"); continuar protegida, abra as #strong[Propriedades] dela → aba #emph[Segurança] e conceda #strong[Controle total] (escrita) ao seu usuário.

]
, 
title: 
[
Atenção no Windows: biblioteca gravável e instalação como administrador
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Testando o Rtools (com um único pacote)
<testando-o-rtools-com-um-único-pacote>
Não confie; #strong[verifique]. Em vez de descobrir que o Rtools não funciona só lá na frente, testamos agora. Instalamos #strong[um] pacote --- o #NormalTok("pkgbuild"); --- e pedimos a ele que tente compilar um programinha. Se a oficina estiver completa, ele responde que sim.

#block[
#Skylighting(([#FunctionTok("install.packages");#NormalTok("(");#StringTok("\"pkgbuild\"");#NormalTok(")");],
[#NormalTok("pkgbuild");#SpecialCharTok("::");#FunctionTok("has_build_tools");#NormalTok("(");#AttributeTok("debug =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],));
]
Se aparecer #NormalTok("TRUE"); (e nenhuma reclamação sobre ferramentas ausentes), o Rtools está pronto.

E não se preocupe: o #NormalTok("pkgbuild"); não é um pacote "descartável". Ele é justamente a engrenagem que o #NormalTok("remotes"); e o #NormalTok("devtools"); usam para #strong[construir pacotes a partir do código-fonte], exatamente o que acontece quando você instala um pacote do GitHub (como o #NormalTok("EAPADados");, daqui a pouco) ou um pacote escrito em C/C++. É nesses casos que o Rtools entra em ação. Pacotes que já chegam prontos (binários do CRAN, como o #NormalTok("jsonlite");) ou feitos só em R (como o #NormalTok("psych");) #strong[não] exercitam o Rtools; por isso o teste do #NormalTok("pkgbuild");, que compila um programinha de verdade, é o mais confiável de todos.

== Os pacotes do ambiente de análise
<os-pacotes-do-ambiente-de-análise>
O R "puro" já faz muita coisa, mas o trabalho fica bem mais agradável com alguns pacotes de apoio. Estes são os do #strong[ambiente geral], que você vai usar o tempo todo, em quase todos os capítulos:

#block[
#Skylighting(([#FunctionTok("install.packages");#NormalTok("(");#FunctionTok("c");#NormalTok("(");],
[#NormalTok("  ");#StringTok("\"tidyverse\"");#NormalTok(",  ");#CommentTok("# manipular dados e fazer gráficos (dplyr, ggplot2, tidyr, readr...)");],
[#NormalTok("  ");#StringTok("\"ggpubr\"");#NormalTok(",     ");#CommentTok("# gráficos prontos para publicação, com aparência limpa");],
[#NormalTok("  ");#StringTok("\"readxl\"");#NormalTok(",     ");#CommentTok("# ler planilhas .xlsx");],
[#NormalTok("  ");#StringTok("\"janitor\"");#NormalTok(",    ");#CommentTok("# limpar nomes de colunas (clean_names) e arrumar tabelas");],
[#NormalTok("  ");#StringTok("\"rio\"");#NormalTok(",        ");#CommentTok("# importar/exportar vários formatos com um comando só");],
[#NormalTok("  ");#StringTok("\"here\"");#NormalTok(",       ");#CommentTok("# montar caminhos a partir da raiz do projeto");],
[#NormalTok("  ");#StringTok("\"rprojroot\"");#NormalTok(",  ");#CommentTok("# localizar a raiz do projeto (motor por trás do here)");],
[#NormalTok("  ");#StringTok("\"fs\"");#NormalTok("          ");#CommentTok("# manipular arquivos e pastas de forma robusta e multiplataforma");],
[#NormalTok("))");],));
]
Os três últimos (#NormalTok("here");, #NormalTok("rprojroot"); e #NormalTok("fs");) merecem uma palavra, porque são a base da #strong[reprodutibilidade]. Em vez de escrever caminhos fixos como #NormalTok("C:/Users/voce/dados/peixes.csv"); (que quebram no computador de qualquer outra pessoa), eles encontram a #strong[raiz do projeto] e montam caminhos relativos que funcionam em qualquer máquina e em qualquer sistema. Você vai usá-los já no próximo capítulo, quando organizarmos um projeto de análise de verdade.

#quote(block: true)[
#strong[Atenção ao escopo.] Aqui ficam só os pacotes de uso #strong[geral]. Os pacotes de #strong[dependência] do #NormalTok("EAPADados"); e da CatalyseR vêm junto quando você instala esses dois (próxima seção); não precisa instalar à mão. E os pacotes #strong[específicos de um capítulo] (por exemplo, #NormalTok("sf");/#NormalTok("leaflet"); para mapas, ou #NormalTok("forecast"); para séries temporais) são pesados e nem todo leitor vai usar: instale-os #strong[quando chegar ao capítulo], não agora. À medida que o livro crescer, esta lista geral pode ganhar um ou outro item, mas o princípio continua: a bancada geral leve, o específico sob demanda.
]

== O pacote do livro: EAPADados
<o-pacote-do-livro-eapadados>
Todos os exemplos deste livro usam dados reais de pesca e aquicultura, reunidos no pacote #strong[#NormalTok("EAPADados");]. Ele não está no CRAN; instalamos direto do GitHub com a ajuda do #NormalTok("remotes");:

#block[
#Skylighting(([#FunctionTok("install.packages");#NormalTok("(");#StringTok("\"remotes\"");#NormalTok(")");],
[#NormalTok("remotes");#SpecialCharTok("::");#FunctionTok("install_github");#NormalTok("(");#StringTok("\"astuciasnor/EAPADados\"");#NormalTok(")");],));
]
Pronto: a partir daqui, sempre que um capítulo disser #NormalTok("data(nome)"); ou #NormalTok("EAPADados::nome");, os dados estarão à mão. Falta a última peça, e a mais importante para este livro: a #strong[CatalyseR], a IDE que abre a análise no mouse.

== A IDE do livro: instalando a CatalyseR
<a-ide-do-livro-instalando-a-catalyser>
A #strong[CatalyseR] (#ref(<fig-logo-catalyser>, supplement: [Figura])) é o coração do nosso método: é nela que você faz a análise apontando e clicando e, ao final, leva embora o #strong[script R] que a reproduz e um #strong[relatório pronto]. Como o #NormalTok("EAPADados");, ela também mora no GitHub e não no CRAN. Mas, diferente de um pacote de dados, a CatalyseR é um #strong[aplicativo] (construído em Shiny) e traz mais dependências junto; por isso vale instalar com um pouco de cuidado, para não tropeçar.

#figure([
#box(image("capitulos\\capitulo02/../../images/logo_catalyser.png", width: 25.0%))
], caption: figure.caption(
position: bottom, 
[
A logo da CatalyseR, a IDE que abre a análise no mouse.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-logo-catalyser>


O segredo para a instalação não falhar é um só: #strong[comece numa sessão limpa e com os utilitários atualizados]. Boa parte dos erros ao instalar pacotes do GitHub não vem do pacote em si, mas de uma engrenagem auxiliar #strong[desatualizada e já carregada] na memória do R. O exemplo mais comum é o pacote #NormalTok("xfun"); (uma peça que o #NormalTok("knitr"); e o #NormalTok("markdown"); usam para gerar relatórios): se uma versão antiga dele já estiver carregada, o R interrompe a instalação com mensagens como #emph["namespace 'xfun' x.y is being loaded, but \>= a.b is required"] ou #emph["cannot remove prior installation of package 'xfun'"]. A cura é simples: atualizar esses utilitários antes, numa sessão recém-aberta.

Faça assim, em uma sessão nova do R (no RStudio, menu #emph[Session → Restart R]), #strong[sem carregar nenhum pacote ainda]:

#block[
#Skylighting(([#CommentTok("# 1) Atualize os utilitários que a CatalyseR e seus relatórios usam.");],
[#CommentTok("#    Um xfun antigo já carregado é a causa nº 1 de falha de instalação.");],
[#FunctionTok("install.packages");#NormalTok("(");#FunctionTok("c");#NormalTok("(");#StringTok("\"remotes\"");#NormalTok(", ");#StringTok("\"xfun\"");#NormalTok(", ");#StringTok("\"knitr\"");#NormalTok(", ");#StringTok("\"markdown\"");#NormalTok("))");],
[],
[#CommentTok("# 2) Instale a CatalyseR do GitHub. As demais dependências");],
[#CommentTok("#    (shiny, bslib, DT, ggplot2, readxl) vêm junto, automaticamente.");],
[#NormalTok("remotes");#SpecialCharTok("::");#FunctionTok("install_github");#NormalTok("(");#StringTok("\"astuciasnor/catalyser\"");#NormalTok(")");],));
]
Se o R perguntar se quer atualizar outros pacotes durante a instalação, prefira atualizar (responda #emph[All], opção 1). E, se ele reclamar que #strong[não consegue remover] um pacote porque está "em uso", reinicie o R outra vez e repita, sempre sem carregar pacotes antes. No Windows, é esse "pacote em uso", com o arquivo travado, que causa a maioria dos sustos; a sessão limpa resolve.

Vale lembrar de duas peças que você já montou e das quais a CatalyseR depende: o #strong[Rtools] (caso alguma dependência precise ser compilada; veja a seção de teste, mais atrás) e o #strong[Quarto] (que a IDE usa para gerar os relatórios). Com a bancada deste capítulo pronta, ela tem tudo de que precisa.

Instalada, a interface abre no seu navegador com dois comandos:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(catalyser)");],
[#FunctionTok("run_app");#NormalTok("()   ");#CommentTok("# abre a CatalyseR no navegador");],));
]
=== Um tour pela tela
<um-tour-pela-tela>
A #ref(<fig-catalyser>, supplement: [Figura]) mostra a CatalyseR aberta. Vale reconhecer as quatro regiões, porque elas se repetem em todos os capítulos do livro.

#figure([
#box(image("capitulos\\capitulo02/../../images/catalyser_interface.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
A interface da CatalyseR. No alto, a logo e o #strong[menu de análises], o catálogo do curso (preparar e descrever dados, regressão, testes paramétricos e não paramétricos, multivariada e mais). À esquerda, o #strong[carregamento de dados]: um arquivo local (CSV/Excel) ou um conjunto do próprio #NormalTok("EAPADados");. No centro, os #strong[dados e resultados]. À direita, o #strong[status] e o botão #strong[Exportar Projeto Consolidado], que empacota a análise num Projeto R (.zip) com os scripts e um relatório Quarto: é a ponte "do mouse ao código".
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-catalyser>


No #strong[alto] fica o menu de análises: é o catálogo do livro, e cada item corresponde a um capítulo. À #strong[esquerda], você carrega os dados, de um arquivo seu ou direto do #NormalTok("EAPADados");. No #strong[centro], vê os dados e, conforme avança, os resultados (tabelas e gráficos). E à #strong[direita], além do status do conjunto, está o botão que dá sentido a tudo: #strong[Exportar Projeto Consolidado]. Ele gera um #NormalTok(".zip"); organizado, com os dados, os #NormalTok("scripts/"); R numerados e um #NormalTok("relatorio.qmd");, exatamente no formato de projeto que veremos no próximo capítulo. Você clicou, analisou e saiu com o código na mão. É esse o caminho que o livro inteiro percorre.

#heading(level: 2, numbering: none)[Resumo do capítulo]
<resumo-do-capítulo>
#quote(block: true)[
Monte a bancada #strong[uma vez]: R (motor), RStudio (painel), Rtools (oficina, no Windows) e Quarto (gráfica), nessa ordem, com o Rtools casando a versão do R. #strong[Teste] o Rtools com #NormalTok("pkgbuild::has_build_tools()");. Instale os pacotes #strong[gerais] (#NormalTok("tidyverse");, #NormalTok("ggpubr"); e os de leitura) e o pacote de dados do livro (#NormalTok("EAPADados");). Por fim, instale a #strong[CatalyseR] numa #strong[sessão limpa] e com os utilitários (#NormalTok("xfun");, #NormalTok("knitr");, #NormalTok("markdown");) atualizados antes, para a instalação não falhar, e abra-a com #NormalTok("run_app()");. Deixe os pacotes #strong[específicos de cada capítulo] para a hora em que forem usados.
]

#heading(level: 2, numbering: none)[Para praticar]
<para-praticar>
+ Rode #NormalTok("pkgbuild::has_build_tools(debug = TRUE)"); e confirme que o resultado é #NormalTok("TRUE");.
+ Carregue o #NormalTok("tidyverse"); com #NormalTok("library(tidyverse)"); e veja a lista de pacotes que ele traz junto.
+ Instale o #NormalTok("EAPADados");, rode #NormalTok("library(EAPADados)"); e liste os dados disponíveis com #NormalTok("data(package = \"EAPADados\")");.
+ Numa sessão limpa do R, instale a #NormalTok("catalyser"); (atualizando antes #NormalTok("xfun");, #NormalTok("knitr"); e #NormalTok("markdown");), depois rode #NormalTok("library(catalyser); run_app()"); e confira se a interface abre no navegador.

= Organização de um Projeto de Análise
<organização-de-um-projeto-de-análise>
Ou: como deixar os arquivos em ordem e nunca mais se perder em pastas

\
#block[
#callout(
body: 
[
Três meses depois de terminar uma análise, você abre a pasta do projeto e encontra #NormalTok("dados.csv");, #NormalTok("dados2.csv");, #NormalTok("dados_final.csv");, #NormalTok("dados_final_AGORA.csv"); e um script que lê "aquele arquivo", mas qual? A figura que entrou no artigo sumiu, e ninguém (nem você) lembra de onde veio o número da tabela. Não é falta de capricho; é falta de #strong[estrutura]. E estrutura, felizmente, se monta uma vez e dura o projeto inteiro.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Organizar um projeto não é burocracia: é o que separa uma análise que #strong[se reproduz] de um amontoado de arquivos que só funciona na sua máquina, hoje, com sorte. Neste capítulo montamos um esqueleto simples de pastas, aprendemos a escrever caminhos que não quebram quando o projeto muda de computador, e percorremos o caminho do dado #strong[bruto] até o dado #strong[limpo], pronto para analisar.

== Um lugar para cada coisa
<um-lugar-para-cada-coisa>
Pense numa cozinha profissional. Os ingredientes crus ficam de um lado, os preparados de outro, as panelas num lugar, os pratos prontos noutro. Ninguém guarda peixe fresco na gaveta dos talheres. Um projeto de análise funciona igual: cada tipo de arquivo tem seu lugar, e isso sozinho já evita metade das dores de cabeça. A #ref(<fig-estrutura>, supplement: [Figura]) mostra o esqueleto que recomendamos.

#figure([
#box(image("capitulos\\capitulo03/../../images/estrutura_projeto.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Estrutura recomendada de um projeto de análise (na raiz, a pasta #NormalTok("projeto-analise/");), item a item: o #NormalTok(".Rproj"); que abre tudo no RStudio, o #NormalTok("README"); que serve de mapa, e as pastas que separam os dados (brutos e limpos), os scripts, as imagens, os resultados e os relatórios, com o que cada uma serve e exemplos do que guarda. O projeto que a CatalyseR exporta segue o mesmo espírito, em versão enxuta.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-estrutura>


A lógica é direta. Os #strong[dados brutos] --- o arquivo exatamente como você recebeu ou coletou --- entram em #NormalTok("dados/brutos/"); e #strong[nunca] são editados; são a sua fonte original, o equivalente ao peixe fresco que você não estraga. Os #strong[dados limpos], depois de tratados, vão para #NormalTok("dados/limpos/");: assim, se algo der errado, você sempre pode recomeçar do bruto. Em #NormalTok("scripts/"); mora o código #NormalTok(".R"); que faz o trabalho; #NormalTok("imagens/"); guarda as figuras exportadas; #NormalTok("resultados/"); guarda tabelas e modelos salvos; e #NormalTok("relatorios/"); reúne os documentos finais: o #NormalTok(".qmd");, o #NormalTok(".docx");, o #NormalTok(".pdf");.

E o #strong[#NormalTok("README");] (aquele arquivo que parece supérfluo) é o #strong[mapa] do projeto. Em poucas linhas, ele diz o que o projeto faz, de onde vieram os dados e como rodar a análise. Parece exagero hoje; mas é o bilhete que o seu "eu do futuro" (ou um colega que herdar o projeto) vai agradecer quando abrir a pasta sem lembrar de mais nada. Não é obrigatório para um rascunho de cinco minutos, mas é o seguro mais barato da reprodutibilidade.

#quote(block: true)[
#strong[Do mouse ao código.] Quando você termina uma análise na CatalyseR e pede para #strong[exportar o Projeto R (.zip)], ela entrega exatamente nesse espírito: um #NormalTok("projeto_analise.Rproj");, a pasta #NormalTok("dados/"); (com os dados limpos), #NormalTok("scripts/"); (o código e as funções) e #NormalTok("relatorios/"); (o #NormalTok(".qmd"); e o modelo de Word), mais um #NormalTok("README");. A estrutura deste capítulo é a versão completa, para os seus próprios projetos; a que a IDE baixa é o subconjunto enxuto, pronto para uma análise específica.
]

== Caminhos que não quebram: o pacote #NormalTok("here");
<caminhos-que-não-quebram-o-pacote-here>
Aqui mora um dos erros mais comuns --- e mais frustrantes --- de quem começa. É tentador escrever o caminho completo de um arquivo:

#Skylighting(([#NormalTok("dados ");#OtherTok("<-");#NormalTok(" readr");#SpecialCharTok("::");#FunctionTok("read_csv");#NormalTok("(");#StringTok("\"C:/Users/voce/Documents/projeto/dados/brutos/capturas.csv\"");#NormalTok(")");],));
Esse caminho funciona… na sua máquina, nesta pasta, hoje. Mande o projeto para um colega, mova a pasta de lugar, ou só troque de computador, e ele quebra. Há um problema mais sutil ainda: o R tem uma "pasta de trabalho" (o #emph[working directory]), e ela #strong[muda] dependendo de como você roda o código: em especial quando o Quarto renderiza um relatório, ele roda a partir da pasta do próprio #NormalTok(".qmd");, não da raiz do projeto. Resultado: o mesmo #NormalTok("read_csv(\"dados/brutos/...\")"); funciona quando você testa no console e falha na hora de renderizar.

O pacote #strong[#NormalTok("here");] resolve isso com uma ideia simples: ele #strong[encontra a raiz do projeto] (a pasta onde está o #NormalTok(".Rproj");) e monta todos os caminhos a partir dela, sempre os mesmos, não importa de onde o R esteja rodando.

#Skylighting(([#FunctionTok("library");#NormalTok("(here)");],
[],
[#CommentTok("# A partir da raiz do projeto, sempre:");],
[#NormalTok("here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"brutos\"");#NormalTok(", ");#StringTok("\"capturas.csv\"");#NormalTok(")");],
[#CommentTok("#> \"C:/Users/voce/Documents/projeto/dados/brutos/capturas.csv\"");],
[],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" readr");#SpecialCharTok("::");#FunctionTok("read_csv");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"brutos\"");#NormalTok(", ");#StringTok("\"capturas.csv\"");#NormalTok("))");],));
Você descreve o caminho em "peças" (#NormalTok("\"dados\"");, #NormalTok("\"brutos\"");, #NormalTok("\"capturas.csv\"");) e o #NormalTok("here"); junta tudo corretamente para o seu sistema, funcione ele no Windows, no Mac ou no Linux. É a diferença entre um caminho que #strong[descreve onde o arquivo está dentro do projeto] e um que #strong[fixa onde a pasta estava naquele dia].

#quote(block: true)[
#strong[A pegadinha das imagens.] Aqui está o ponto que mais confunde. Para o #strong[R ler] algo (um #NormalTok(".csv");, ou exibir uma figura com #NormalTok("knitr::include_graphics()");), use o #NormalTok("here");\; ele é robusto. Mas para #strong[inserir] uma imagem direto no texto com a sintaxe de Markdown, #NormalTok("![legenda](caminho)");, quem resolve o caminho é o #strong[Quarto], e ele o faz #strong[relativo ao arquivo #NormalTok(".qmd");], não pelo #NormalTok("here");. São dois mundos: o caminho que o R enxerga (resolvido pelo #NormalTok("here");, a partir da raiz) e o caminho que o Markdown enxerga (relativo ao documento). Misturar os dois é a causa nº 1 de "a imagem não aparece". A regra prática: imagem #strong[estática no texto] → caminho relativo ao #NormalTok(".qmd");\; imagem #strong[gerada ou inserida por código R] → #NormalTok("knitr::include_graphics(here::here(\"imagens\", \"fig.png\"))");.
]

== Uma planilha que o R entende: o formato #emph[tidy]
<uma-planilha-que-o-r-entende-o-formato-tidy>
Antes de falar em ler dados, vale falar em #strong[digitá-los direito]. A maior parte do sofrimento numa análise não nasce no R, nasce na planilha de campo, montada para o olho humano e não para o computador. Título mesclado no topo, a unidade colada no número ("612 g"), uma linha de "média" no meio das observações, duas mini-tabelas lado a lado, cor amarela marcando "isso aqui é especial". Tudo isso é informação que #strong[você] entende, mas que o R não tem como ler.

A receita que resolve quase tudo se chama #strong[dados #emph[tidy]] (dados "arrumados"), e cabe em três regras: #strong[cada variável é uma coluna], #strong[cada observação é uma linha], e há #strong[um único cabeçalho], na primeira linha. A #ref(<fig-tidy>, supplement: [Figura]) mostra a mesma biometria de peixes nos dois mundos: a planilha bonita para humanos (e ilegível para o R) e a planilha #emph[tidy].

#figure([
#box(image("capitulos\\capitulo03/../../images/tidy_dados.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
A mesma biometria de campo em dois formatos. À esquerda, a planilha "para humanos": título mesclado, unidades dentro das células, um total no meio dos dados e cor como informação, que o R não consegue ler. À direita, o formato #emph[tidy]: uma variável por coluna, um peixe por linha, cabeçalho único e valores puros. Digite os dados brutos já assim.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-tidy>


Repare que, no formato #emph[tidy], o que antes estava na cor ou no título virou #strong[coluna]: o local de coleta deixou de ser um cabeçalho amarelo e passou a ser a variável #NormalTok("local");\; a data, que estava só no título, virou a coluna #NormalTok("data");. Nada se perde: tudo vira dado. E uma planilha #emph[tidy] não é só mais limpa: é a forma que o #NormalTok("ggplot2");, o #NormalTok("dplyr"); e as funções da CatalyseR #strong[esperam] receber. Organizar na entrada economiza horas de remendo depois.

Nem sempre, porém, dá para organizar na origem --- muitos dados chegam prontos, em formato #strong[largo] (uma coluna por ano, por exemplo) ou com informação espremida dentro de uma célula. Quando for esse o caso, o passo de #strong[reformatar] a tabela para #emph[tidy] --- empilhar, alargar, separar --- tem capítulo próprio: o Capítulo 5, já na Unidade II.

== Do bruto ao limpo
<do-bruto-ao-limpo>
Com a estrutura no lugar e os caminhos resolvidos, o fluxo de trabalho fica natural: #strong[ler] o dado bruto, #strong[limpar], e #strong[gravar] a versão tratada. Tudo apontando para as pastas certas.

A leitura aceita vários formatos. Para um #NormalTok(".csv");, o #NormalTok("readr");\; para uma planilha do Excel, o #NormalTok("readxl");\; e se você não quiser decorar funções, o #NormalTok("rio"); importa quase tudo com um comando só:

#Skylighting(([#FunctionTok("library");#NormalTok("(readr); ");#FunctionTok("library");#NormalTok("(readxl); ");#FunctionTok("library");#NormalTok("(rio)");],
[],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" readr");#SpecialCharTok("::");#FunctionTok("read_csv");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"brutos\"");#NormalTok(", ");#StringTok("\"capturas.csv\"");#NormalTok("))");],
[#CommentTok("# ou, de uma planilha (aba 1):");],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" readxl");#SpecialCharTok("::");#FunctionTok("read_excel");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"brutos\"");#NormalTok(", ");#StringTok("\"capturas.xlsx\"");#NormalTok("), ");#AttributeTok("sheet =");#NormalTok(" ");#DecValTok("1");#NormalTok(")");],
[#CommentTok("# ou deixe o rio adivinhar o formato:");],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" rio");#SpecialCharTok("::");#FunctionTok("import");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"brutos\"");#NormalTok(", ");#StringTok("\"capturas.xlsx\"");#NormalTok("))");],));
Antes de analisar, vale #strong[arrumar a casa]: padronizar os nomes das colunas, acertar os tipos das variáveis (espécie vira fator, peso vira número) e remover duplicatas. O #NormalTok("janitor"); cuida dos nomes; o #NormalTok("dplyr");, do resto:

#Skylighting(([#FunctionTok("library");#NormalTok("(dplyr); ");#FunctionTok("library");#NormalTok("(janitor)");],
[],
[#NormalTok("dados_limpos ");#OtherTok("<-");#NormalTok(" dados ");#SpecialCharTok("|>");],
[#NormalTok("  janitor");#SpecialCharTok("::");#FunctionTok("clean_names");#NormalTok("() ");#SpecialCharTok("|>");#NormalTok("                 ");#CommentTok("# nomes padronizados, sem acento/espaço");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("especie =");#NormalTok(" ");#FunctionTok("as.factor");#NormalTok("(especie),");],
[#NormalTok("         ");#AttributeTok("peso_g  =");#NormalTok(" ");#FunctionTok("as.numeric");#NormalTok("(peso_g)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("distinct");#NormalTok("()                                 ");#CommentTok("# fora as duplicatas");],));
E então #strong[grave a versão limpa] numa pasta separada, preservando o bruto intacto:

#Skylighting(([#NormalTok("rio");#SpecialCharTok("::");#FunctionTok("export");#NormalTok("(dados_limpos, here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.csv\"");#NormalTok("))");],));
Há um detalhe que o #NormalTok(".csv"); não resolve: ele #strong[esquece os tipos]. Como é só texto separado por vírgulas, na próxima leitura uma coluna que era fator vira texto, uma data vira texto, e você precisa rearrumar tudo de novo. Quando o trabalho vai continuar #strong[dentro do R], a melhor escolha é o formato nativo dele, o #strong[#NormalTok(".rda");] (ou o #NormalTok(".rds");, sua versão de um objeto só). Ele guarda o objeto exatamente como está na memória (classes, fatores, níveis, atributos) e carrega num piscar de olhos. É inclusive o formato em que vivem os dados do #NormalTok("EAPADados");:

#Skylighting(([#CommentTok("# salvar e ler um único objeto (recomendado): .rds");],
[#FunctionTok("saveRDS");#NormalTok("(dados_limpos, here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.rds\"");#NormalTok("))");],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("readRDS");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.rds\"");#NormalTok("))");],
[],
[#CommentTok("# salvar objetos com nome (um ou vários): .rda");],
[#FunctionTok("save");#NormalTok("(dados_limpos, ");#AttributeTok("file =");#NormalTok(" here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.rda\"");#NormalTok("))");],
[#FunctionTok("load");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.rda\"");#NormalTok("))   ");#CommentTok("# devolve 'dados_limpos'");],));
#strong[E se você também usa Python?] O #NormalTok(".rda");/#NormalTok(".rds"); é perfeito para quem fica no R, mas só o R o entende. Se precisar trocar dados com o Python (ou outras ferramentas) sem perder os tipos, salve em #strong[Parquet], com o pacote #NormalTok("arrow");. O mesmo arquivo, depois, abre direto no pandas, do lado do Python:

#Skylighting(([#FunctionTok("library");#NormalTok("(arrow)");],
[],
[#CommentTok("# salvar preservando os tipos (lê em R e em Python)");],
[#NormalTok("arrow");#SpecialCharTok("::");#FunctionTok("write_parquet");#NormalTok("(dados_limpos, here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.parquet\"");#NormalTok("))");],
[],
[#CommentTok("# ler de volta: cada coluna volta com o tipo certo");],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" arrow");#SpecialCharTok("::");#FunctionTok("read_parquet");#NormalTok("(here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"capturas.parquet\"");#NormalTok("))");],));
== Tratamento na prática: capturas de pescada-amarela
<tratamento-na-prática-capturas-de-pescada-amarela>
A teoria do "ler → limpar → gravar" fica muito mais clara num dado de verdade --- com a sujeira de verdade. Vamos usar um conjunto real do nosso grupo de pesquisa: registros de #strong[captura de pescada-amarela] por sete embarcações (B1 a B7), mês a mês, entre 2019 e 2021, com a CPUE de cada viagem, o esforço (dias ao mar, pessoal embarcado), o aparelho de pesca e variáveis ambientais como precipitação e período sazonal. São dados ainda não publicados, exatamente como saíram do campo --- e é por isso que servem tão bem: trazem os defeitos que todo dado real tem. Eles acompanham o pacote #NormalTok("EAPADados"); em duas versões irmãs: a #strong[bruta] (#NormalTok("captura_pescada_amarela_bruta");), que vamos limpar aqui, e a #strong[tratada] (#NormalTok("captura_pescada_amarela");), usada nas análises das Unidades IV e V.

Vamos lê-lo e olhar de perto.

#Skylighting(([#FunctionTok("library");#NormalTok("(dplyr); ");#FunctionTok("library");#NormalTok("(janitor); ");#FunctionTok("library");#NormalTok("(stringr); ");#FunctionTok("library");#NormalTok("(lubridate)");],
[],
[#CommentTok("# o conjunto BRUTO vive no EAPADados, mantido de propósito com os defeitos de campo");],
[#FunctionTok("data");#NormalTok("(");#StringTok("\"captura_pescada_amarela_bruta\"");#NormalTok(", ");#AttributeTok("package =");#NormalTok(" ");#StringTok("\"EAPADados\"");#NormalTok(")");],
[#NormalTok("bruto ");#OtherTok("<-");#NormalTok(" captura_pescada_amarela_bruta");],
[],
[#FunctionTok("names");#NormalTok("(bruto)");],
[#CommentTok("#> \"Embarcacao\"  \"Tamanho (m)\"  \"Precipitação\"  \"Mês\"  \"Ano\"");],
[#CommentTok("#> \"Período sazonal\"  \"Mês/ano\"  \"Data de Saida\" ...");],));
O primeiro problema está logo nos #strong[nomes das colunas]: acento em "Precipitação" e "Mês", espaço e parêntese em "Tamanho (m)", uma barra em "Mês/ano". Nomes assim obrigam você a escrever #NormalTok("dados$`Tamanho (m)`"); com crases pelo resto da vida. O #NormalTok("janitor::clean_names()"); resolve tudo de uma vez:

#Skylighting(([#NormalTok("dados ");#OtherTok("<-");#NormalTok(" bruto ");#SpecialCharTok("|>");#NormalTok(" janitor");#SpecialCharTok("::");#FunctionTok("clean_names");#NormalTok("()");],
[#FunctionTok("names");#NormalTok("(dados)");],
[#CommentTok("#> \"embarcacao\"  \"tamanho_m\"  \"precipitacao\"  \"mes\"  \"ano\"");],
[#CommentTok("#> \"periodo_sazonal\"  \"mes_ano\"  \"data_de_saida\" ...");],));
Agora o defeito mais traiçoeiro --- e mais comum. Vamos contar as categorias de #NormalTok("periodo_sazonal");:

#Skylighting(([#FunctionTok("table");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("periodo_sazonal)");],
[#CommentTok("#> chuvoso  chuvoso     seco    seco ");],
[#CommentTok("#>     105       21      105      21 ");],));
Quatro categorias?! Deveriam ser #strong[duas]. Acontece que algumas células foram digitadas com um #strong[espaço sobrando] no fim --- "chuvoso" (com espaço) é diferente de "chuvoso" para o computador, ainda que idênticas para você. O olho não vê, mas o R conta como grupos distintos, e isso bagunçaria qualquer comparação por estação. O mesmo ocorre com o aparelho de pesca ("Espinhel" vs.~"Espinhel"). A cura é aparar os espaços com #NormalTok("str_squish()");, que remove sobras no começo, no fim e duplicadas no meio:

#Skylighting(([#NormalTok("dados ");#OtherTok("<-");#NormalTok(" dados ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("periodo_sazonal     =");#NormalTok(" ");#FunctionTok("str_squish");#NormalTok("(periodo_sazonal),");],
[#NormalTok("    ");#AttributeTok("nome_aparelho_pesca =");#NormalTok(" ");#FunctionTok("str_squish");#NormalTok("(nome_aparelho_pesca)");],
[#NormalTok("  )");],
[],
[#FunctionTok("table");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("periodo_sazonal)");],
[#CommentTok("#> chuvoso    seco");],
[#CommentTok("#>     126     126");],));
Duas categorias, como deveria ser. Esse é o tipo de erro que não dá mensagem nenhuma: ele só aparece se você #strong[olhar] as categorias --- mais uma razão para a etapa exploratória da Unidade II.

Em seguida, as #strong[datas]. Ao converter a data de chegada, o #NormalTok("lubridate"); reclama de um valor:

#Skylighting(([#NormalTok("dados ");#OtherTok("<-");#NormalTok(" dados ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("data_de_chegada =");#NormalTok(" ");#FunctionTok("dmy");#NormalTok("(data_de_chegada))");],
[#CommentTok("#> Warning: 1 failed to parse.");],));
Um aviso desses nunca deve ser ignorado. Procurando o culpado, achamos um #NormalTok("\"15/10//2020\""); --- uma barra digitada a mais. Sem saber o que fazer com aquilo, o R o transformou em #NormalTok("NA");. Identificado o erro, corrige-se na origem (ou no código) e relê-se. A lição vale por todo o livro: #strong[avisos de #emph[parsing] são pistas, não ruído.]

Faltam os #strong[tipos]. O mês veio como texto, e texto se ordena em ordem alfabética --- "Abril" antes de "Janeiro" ---, o que deixaria qualquer gráfico mensal sem sentido. Declaramos #NormalTok("mes"); como um #strong[fator ordenado] no calendário; de passagem, transformamos em fator as demais categóricas e arredondamos a CPUE, que veio com casas decimais demais:

#Skylighting(([#NormalTok("meses ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"Janeiro\"");#NormalTok(",");#StringTok("\"Fevereiro\"");#NormalTok(",");#StringTok("\"Março\"");#NormalTok(",");#StringTok("\"Abril\"");#NormalTok(",");#StringTok("\"Maio\"");#NormalTok(",");#StringTok("\"Junho\"");#NormalTok(",");],
[#NormalTok("           ");#StringTok("\"Julho\"");#NormalTok(",");#StringTok("\"Agosto\"");#NormalTok(",");#StringTok("\"Setembro\"");#NormalTok(",");#StringTok("\"Outubro\"");#NormalTok(",");#StringTok("\"Novembro\"");#NormalTok(",");#StringTok("\"Dezembro\"");#NormalTok(")");],
[],
[#NormalTok("dados ");#OtherTok("<-");#NormalTok(" dados ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("embarcacao          =");#NormalTok(" ");#FunctionTok("as.factor");#NormalTok("(embarcacao),");],
[#NormalTok("    ");#AttributeTok("periodo_sazonal     =");#NormalTok(" ");#FunctionTok("as.factor");#NormalTok("(periodo_sazonal),");],
[#NormalTok("    ");#AttributeTok("nome_aparelho_pesca =");#NormalTok(" ");#FunctionTok("as.factor");#NormalTok("(nome_aparelho_pesca),");],
[#NormalTok("    ");#AttributeTok("mes  =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(mes, ");#AttributeTok("levels =");#NormalTok(" meses),   ");#CommentTok("# ordem de calendário, não alfabética");],
[#NormalTok("    ");#AttributeTok("cpue =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(cpue, ");#DecValTok("2");#NormalTok(")                 ");#CommentTok("# casas decimais sob controle");],
[#NormalTok("  )");],));
Com a casa arrumada, grava-se a versão limpa --- e o que entrou como uma planilha cheia de armadilhas sai como um conjunto #emph[tidy], tipado e pronto para a análise. É exatamente essa a versão que o #NormalTok("EAPADados"); disponibiliza como #NormalTok("captura_pescada_amarela");, pronta para #NormalTok("data(captura_pescada_amarela)"); nos capítulos seguintes:

#Skylighting(([#FunctionTok("saveRDS");#NormalTok("(dados, here");#SpecialCharTok("::");#FunctionTok("here");#NormalTok("(");#StringTok("\"dados\"");#NormalTok(", ");#StringTok("\"limpos\"");#NormalTok(", ");#StringTok("\"captura_pescada_amarela.rds\"");#NormalTok("))");],));
#block[
#callout(
body: 
[
Antes de analisar, passe esta régua: nomes de coluna padronizados; categorias sem espaços fantasmas nem grafias repetidas; datas e números no tipo certo (e fatores ordinais com a ordem certa); avisos de leitura investigados, não ignorados. Cinco minutos aqui poupam horas de análise refeita.

]
, 
title: 
[
A régua do dado limpo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Tabela-resumo dos principais comandos
<tabela-resumo-dos-principais-comandos>
Para consulta rápida, a #ref(<tbl-comandos>, supplement: [Tabela]) reúne os comandos deste capítulo.

#set page(flipped: true)
#figure([
#table(
  columns: (20%, 16%, 9%, 55%),
  align: (left,left,left,left,),
  table.header([Ação], [Função], [Pacote], [Exemplo],),
  table.hline(),
  [Caminho a partir da raiz], [#NormalTok("here()");], [here], [#NormalTok("here::here(\"dados\", \"brutos\", \"arq.csv\")");],
  [Ler CSV], [#NormalTok("read_csv()");], [readr], [#NormalTok("read_csv(here::here(\"dados\", \"brutos\", \"arq.csv\"))");],
  [Ler Excel], [#NormalTok("read_excel()");], [readxl], [#NormalTok("read_excel(here::here(\"dados\", \"brutos\", \"arq.xlsx\"), sheet = 1)");],
  [Importar (qualquer formato)], [#NormalTok("import()");], [rio], [#NormalTok("import(here::here(\"dados\", \"brutos\", \"arq.xlsx\"))");],
  [Limpar nomes de colunas], [#NormalTok("clean_names()");], [janitor], [#NormalTok("clean_names(dados)");],
  [Exportar (qualquer formato)], [#NormalTok("export()");], [rio], [#NormalTok("export(dados_limpos, here::here(\"dados\", \"limpos\", \"arq.csv\"))");],
  [Salvar preservando tipos], [#NormalTok("write_parquet()");], [arrow], [#NormalTok("write_parquet(dados_limpos, here::here(\"dados\", \"limpos\", \"arq.parquet\"))");],
  [Ler Parquet], [#NormalTok("read_parquet()");], [arrow], [#NormalTok("read_parquet(here::here(\"dados\", \"limpos\", \"arq.parquet\"))");],
  [Aparar espaços de texto], [#NormalTok("str_squish()");], [stringr], [#NormalTok("str_squish(periodo_sazonal)");],
  [Converter data], [#NormalTok("dmy()");], [lubridate], [#NormalTok("dmy(data_de_chegada)");],
  [Fator com ordem definida], [#NormalTok("factor()");], [base], [#NormalTok("factor(mes, levels = meses)");],
)
], caption: figure.caption(
position: top, 
[
Principais comandos de organização, leitura e gravação de dados no projeto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-comandos>


#set page(flipped: false)
== Versione desde o primeiro dia
<versione-desde-o-primeiro-dia>
Por fim, uma recomendação que vale ouro: use #strong[Git] desde o início, mesmo sozinho. Ele guarda o histórico das mudanças nos seus scripts, permite voltar a qualquer versão e torna a colaboração simples. Versionar #strong[código] é regra; versionar #strong[dados] só vale para arquivos pequenos (os grandes ficam de fora, anotados no #NormalTok("README");). Não é coisa só de programador, é a sua máquina do tempo.

#heading(level: 2, numbering: none)[Resumo do capítulo]
<resumo-do-capítulo-1>
#quote(block: true)[
Dê a cada arquivo um lugar: #strong[brutos] intocados, #strong[limpos] tratados, e pastas separadas para scripts, imagens, resultados e relatórios, com um #strong[README] de mapa. Escreva caminhos com #strong[#NormalTok("here");], que parte da raiz do projeto e funciona em qualquer máquina (lembrando que imagem no texto Markdown segue o caminho relativo ao #NormalTok(".qmd");). Siga o fluxo #strong[ler → limpar → gravar], mantendo o bruto intacto, e prefira #strong[Parquet] quando quiser preservar os tipos. É o mesmo espírito do projeto que a CatalyseR exporta para você completar no RStudio.
]

#heading(level: 2, numbering: none)[Para praticar]
<para-praticar-1>
+ Crie um projeto no RStudio (com #NormalTok(".Rproj");) e monte as pastas da #ref(<fig-estrutura>, supplement: [Figura]). Escreva um #NormalTok("README"); de três linhas: o que é, de onde vêm os dados, como rodar.
+ Coloque um #NormalTok(".csv"); qualquer em #NormalTok("dados/brutos/");, leia-o com #NormalTok("here::here(...)");, padronize os nomes com #NormalTok("janitor::clean_names()"); e grave a versão limpa em #NormalTok("dados/limpos/");.
+ Salve o mesmo dado em #NormalTok(".csv"); e em #NormalTok(".parquet");. Leia os dois de volta e compare as classes das colunas com #NormalTok("str()");\; veja o que o Parquet preserva e o CSV esquece.
+ Pegue a planilha "para humanos" da #ref(<fig-tidy>, supplement: [Figura]) (à esquerda) e #strong[reorganize-a] no formato #emph[tidy] (à direita): uma coluna por variável, um peixe por linha, cabeçalho único, sem unidades nem cores. Depois leia o resultado no R e confira com #NormalTok("str()"); se cada coluna ficou com o tipo certo.

#part[Unidade II · Antes da análise — planejar a pesquisa e conhecer os dados]
= Planejando sua Pesquisa
<planejando-sua-pesquisa>
Ou: a análise certa começa muito antes do primeiro número

\
#block[
#callout(
body: 
[
O barco está abastecido, a rede a postos, e você prestes a embarcar. Mas pare um instante: #emph[você já sabe exatamente o que vai medir lá fora?] Quais variáveis anotar a cada lance, em que unidade pesar a captura, onde e quando soltar a rede? Se a resposta não estiver pronta #strong[antes] de soltar as amarras, nenhum software conserta depois. O planejamento acontece em terra --- e é ele que decide quais análises serão possíveis.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Começa aqui a unidade #strong[Antes da análise], e o nome diz a que veio: quase tudo que decide a qualidade de um estudo acontece #emph[antes] de apertar o botão do teste. O caminho é #strong[da pergunta aos dados] --- primeiro a #strong[pergunta], o #strong[desenho] do estudo e as #strong[variáveis] (é o assunto deste capítulo); depois, com os dados em mãos, #strong[organizá-los, descrevê-los e visualizá-los] (o capítulo seguinte). Só ao fim desse trajeto é que se escolhe, com segurança, o procedimento estatístico. É também a primeira vez que os três lados do ecossistema EAPA andam juntos de ponta a ponta: o #strong[livro] explica o raciocínio, o #strong[EAPADados] fornece os dados reais da pesca e da aquicultura, e a #strong[CatalyseR] conduz a análise e exporta o projeto #NormalTok(".qmd"); para você terminar no RStudio.

Há uma ordem natural nas coisas, e ela costuma ser invertida. A pressa é coletar logo, e só na frente do computador perguntar "que teste eu uso agora?". Acontece que essa pergunta tem resposta muito antes: #strong[o tipo de estudo determina os dados que você vai coletar, como coletá-los e como organizá-los] --- e, com isso, decide de antemão quais análises serão possíveis, quais pressupostos elas exigirão e que cuidados a coleta impõe. Planejar a coleta é, na prática, #strong[escolher antecipadamente o teste].

Daí a importância deste capítulo, que talvez seja o mais teórico do livro e, ainda assim, um dos mais decisivos. Não há linha de código que recupere um dado que não foi registrado, nem análise que salve uma amostra colhida no improviso. Por outro lado, um conjunto bem planejado e arrumado desde o início --- na filosofia #emph[tidy], cada linha uma observação, cada coluna uma variável, como vimos na Unidade I --- praticamente se oferece à análise correta.

O planejamento tem dois grandes ramos, e eles dão nome às duas seções deste capítulo, espelhando o menu #strong[Planejando sua Pesquisa] da CatalyseR. Quando observamos a natureza como ela é, sem intervir, fazemos #strong[planejamento observacional]: decidimos #emph[quem] observar e #emph[como sortear] esses indivíduos. Quando intervimos de propósito --- atribuindo tratamentos e controlando condições ---, fazemos #strong[planejamento experimental]. O primeiro descreve e compara o que existe; o segundo permite falar em #strong[causa].

#figure([
#table(
  columns: (26%, 28%, 24%, 22%),
  align: (left,left,left,left,),
  table.header([Ramo (menu CatalyseR)], [O que se faz], [Pergunta típica], [Para onde leva],),
  table.hline(),
  [Planejamentos Observacionais], [observar sem intervir; #strong[sortear] quem observar], [como está a população?], [descrição, comparação, correlação],
  [Planejamentos Experimentais], [#strong[intervir]\; atribuir tratamentos], [qual o efeito de #emph[X] sobre #emph[Y]?], [ANOVA, regressão],
)
], caption: figure.caption(
position: top, 
[
Os dois ramos do planejamento e o que cada um habilita.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-ramos>


== Por que o planejamento vem antes de tudo
<por-que-o-planejamento-vem-antes-de-tudo>
Quase nunca conseguimos medir a população inteira. Não há tempo, combustível nem tripulação para pesar todo o camarão de um estuário ou medir todos os peixes de um açude. Então #strong[amostramos]: tomamos uma parte para inferir sobre o todo. E aqui mora a primeira decisão de peso, porque uma amostra só representa a população se for tomada com honestidade.

A única defesa real contra o viés é o #strong[acaso]. Parece contraintuitivo confiar no sorteio, mas é justamente ele que impede que a amostra reflita as suas preferências em vez da realidade. O "lugar onde sempre pesco" rende mais camarão porque você o escolheu por isso --- e essa escolha contamina qualquer conclusão. Sortear quem entra na amostra é o que torna possível generalizar do pedaço para o todo.

A segunda decisão é o formato. Dados pensados desde a planilha de campo no formato #emph[tidy] chegam ao R prontos para virar fatores, gráficos e testes. Dados anotados de qualquer jeito --- unidades misturadas, totais no meio das observações, cor como informação --- fecham portas que nenhum código reabre. O fio condutor do capítulo é este, e vale repetir: #strong[a forma de coletar decide a forma de analisar].

== Planejamentos Observacionais
<planejamentos-observacionais>
Começamos pelo ramo em que apenas observamos. Aqui o objetivo é descrever uma população ou comparar grupos que já existem --- locais, períodos, sexos --- sem mexer em nada. A ferramenta central é a #strong[amostragem probabilística]: todo indivíduo tem uma probabilidade conhecida de ser sorteado, e é isso que garante a representatividade. A CatalyseR oferece os três métodos mais usados na pesca, e é por eles que vamos.

=== Amostragem Aleatória Simples (AAS)
<amostragem-aleatória-simples-aas>
É a base de tudo, e a ideia não poderia ser mais simples: todo indivíduo da população tem #strong[a mesma chance] de ser sorteado, como tirar nomes de um chapéu. Imagine que o defeso abriu por dezesseis dias e você só tem perna para coletar em quatro deles. Em vez de escolher "os dias de tempo bom" (que enviesariam a captura), você sorteia:

#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("dias_possiveis ");#OtherTok("<-");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("16");],
[#NormalTok("dias_coleta ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(dias_possiveis, ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("4");#NormalTok(")   ");#CommentTok("# sorteio sem reposição");],
[#FunctionTok("sort");#NormalTok("(dias_coleta)");],));
#block[
#Skylighting(([#NormalTok("[1]  1  6  9 13");],));
]
]
Pronto: quatro dias escolhidos pelo acaso, sem a sua mão no meio. A AAS é honesta e fácil, mas tem um ponto cego --- ela ignora qualquer estrutura conhecida da população. Se metade do estuário é mangue e metade é praia, um sorteio simples pode, por azar, cair quase todo num lado só. Quando sabemos que existe essa estrutura, vale usá-la a nosso favor, e é o que faz o método seguinte.

=== Amostragem Estratificada Proporcional (AEP)
<amostragem-estratificada-proporcional-aep>
Estratificar é dividir a população em subgrupos homogêneos --- os #strong[estratos] --- e amostrar dentro de cada um. Se as três áreas de um estuário diferem entre si, elas viram os estratos; aí garantimos que nenhuma fique de fora e, de quebra, já saímos com os grupos prontos para comparar. Na alocação #strong[proporcional], o tamanho da amostra em cada estrato acompanha o tamanho do estrato: áreas maiores recebem mais pontos.

#block[
#Skylighting(([#NormalTok("estratos ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("area =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"Área 1\"");#NormalTok(", ");#StringTok("\"Área 2\"");#NormalTok(", ");#StringTok("\"Área 3\"");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("N    =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("500");#NormalTok(", ");#DecValTok("300");#NormalTok(", ");#DecValTok("200");#NormalTok(")            ");#CommentTok("# tamanho de cada estrato");],
[#NormalTok(")");],
[#NormalTok("n_total ");#OtherTok("<-");#NormalTok(" ");#DecValTok("50");],
[#NormalTok("estratos");#SpecialCharTok("$");#NormalTok("n_h ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("round");#NormalTok("(n_total ");#SpecialCharTok("*");#NormalTok(" estratos");#SpecialCharTok("$");#NormalTok("N ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(estratos");#SpecialCharTok("$");#NormalTok("N))");],
[#NormalTok("estratos");],));
#block[
#Skylighting(([#NormalTok("    area   N n_h");],
[#NormalTok("1 Área 1 500  25");],
[#NormalTok("2 Área 2 300  15");],
[#NormalTok("3 Área 3 200  10");],));
]
]
A maior das áreas levou metade da amostra; a menor, um quinto. Esse é o método certo quando você sabe que um fator --- local, período, profundidade --- influencia forte a resposta: ele protege a comparação ao assegurar que cada subgrupo importante seja representado na medida do seu peso.

=== Amostragem Sistemática (AS)
<amostragem-sistemática-as>
Às vezes a população chega em fila: lances ao longo de um dia, peixes saindo da rede um após o outro, indivíduos numa esteira de triagem. Aí é prático sortear apenas o #strong[ponto de partida] e seguir a intervalos fixos. O passo é $k = N \/ n$ --- a cada $k$ indivíduos, um entra na amostra.

#block[
#Skylighting(([#NormalTok("N ");#OtherTok("<-");#NormalTok(" ");#DecValTok("200");#NormalTok("; n ");#OtherTok("<-");#NormalTok(" ");#DecValTok("8");],
[#NormalTok("k ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("floor");#NormalTok("(N ");#SpecialCharTok("/");#NormalTok(" n)              ");#CommentTok("# passo de amostragem");],
[#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("inicio ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#NormalTok("k, ");#DecValTok("1");#NormalTok(")       ");#CommentTok("# sorteia só o ponto de partida");],
[#NormalTok("amostra ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("seq");#NormalTok("(inicio, ");#AttributeTok("by =");#NormalTok(" k, ");#AttributeTok("length.out =");#NormalTok(" n)");],
[#NormalTok("amostra");],));
#block[
#Skylighting(([#NormalTok("[1]  25  50  75 100 125 150 175 200");],));
]
]
É rápida e cobre a fila de ponta a ponta. O cuidado é com #strong[padrões cíclicos]: se a lista tem um ritmo que coincide com o passo $k$ --- digamos, a rede sempre sobe mais cheia de manhã e você acaba pegando só as manhãs ---, a amostra fica enviesada justamente por causa da regularidade. Quando não há esse risco, a sistemática é uma escolha econômica e elegante.

=== Estudo de caso: captura de camarão por arrasto
<estudo-de-caso-captura-de-camarão-por-arrasto>
Vamos juntar tudo num exemplo real. Queremos avaliar #strong[quanto camarão se captura] ao longo de diferentes períodos do ano e em locais distintos de um estuário --- informação valiosa para a gestão do recurso. Duas perguntas guiam o estudo: #emph[a captura difere entre os locais?] e #emph[o período do ano afeta a quantidade capturada?] Cada pergunta já é, no fundo, uma hipótese à espera de um teste.

A captura é feita por #strong[arrasto], com a embarcação rebocando a rede pelo fundo (#ref(<fig-barco>, supplement: [Figura])). Reparar nesse desenho não é detalhe: o petrecho, a abertura da boca da rede, o tempo de arrasto e a velocidade definem o #strong[esforço de pesca] --- e é esse esforço que precisaremos registrar para que as capturas sejam comparáveis entre si.

#figure([
#box(image("capitulos\\capitulo06/../../images/barco_camarao_arrasto.png", width: 85.0%))
], caption: figure.caption(
position: bottom, 
[
Captura de camarão por arrasto de fundo: a embarcação reboca a rede pelas portas de arrasto, e o camarão se acumula no saco (copo). O esforço de pesca depende do petrecho, da abertura da rede e do tempo de arrasto.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-barco>


Aqui está o coração do planejamento observacional: a lista de variáveis não se improvisa no convés, ela se decide na escrivaninha. Para responder às perguntas, definimos de antemão o que será anotado a cada lance --- #emph[quando e em que condições] (data, fase lunar, vento), #emph[como se pescou] (petrecho e duração do esforço, para padronizar), #emph[o que se capturou] (peso de camarão e da fauna acompanhante, em quilogramas) e #emph[onde] (o local). Note que cada variável já nasce com um #strong[tipo] declarado: fase lunar e local são categóricas; pesos e duração, numéricas contínuas. Decidir o tipo agora é decidir, desde já, o que se poderá calcular depois.

Tão importante quanto #emph[o que] medir é #emph[como] registrar. A captura é pesada a bordo, logo após cada lance, sempre na #strong[mesma unidade] e com o mesmo número de casas decimais. As informações vão primeiro para uma planilha de campo à prova de respingos e só depois são digitalizadas. A #ref(<fig-planilha>, supplement: [Figura]) mostra essa rotina de bordo --- conferir, separar, pesar, registrar lance a lance, num formato que já é quase #emph[tidy]: cada linha um lance, cada coluna uma variável.

#figure([
#box(image("capitulos\\capitulo06/../../images/planilha_coleta_camarao.png", width: 95.0%))
], caption: figure.caption(
position: bottom, 
[
Rotina de arrumação dos dados após cada lance e modelo de planilha de campo: conferir, separar por espécie, pesar, registrar, identificar o lance e conservar. Padronizar unidades e preencher de forma legível garante a rastreabilidade da amostragem.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-planilha>


E o desenho da coleta? Ele combina cuidado no espaço e no tempo. No #strong[espaço], escolhem-se três áreas separadas por alguns quilômetros --- para que sejam de fato distintas ---, e elas funcionam como estratos. No #strong[tempo], cada ponto é visitado em vários momentos distribuídos ao acaso ao longo do estudo, para que nenhuma fase do ano fique sobre ou sub-representada. É, na prática, uma amostragem #strong[estratificada] (as áreas) com #strong[casualização] temporal --- exatamente os métodos que acabamos de ver, trabalhando juntos.

Quando essa planilha estiver pronta, ela alimentará a comparação que motivou o estudo: a #strong[captura por unidade de esforço] (CPUE) entre locais e entre períodos. Como CPUE costuma fugir da normalidade, entra ali um teste não paramétrico como o de Kruskal-Wallis, que veremos na unidade de inferência. O conjunto #NormalTok("captura_petrechos");, do pacote #NormalTok("EAPADados");, traz justamente esse tipo de dado de captura por aparelho de pesca, e será o campo de prática lá adiante. O planejamento que fizemos aqui é o que torna aquela análise possível.

=== Estudo de caso: a força da arrebentação
<estudo-de-caso-a-força-da-arrebentação>
Mudemos de praia --- literalmente. Na orla, a #strong[zona de arrebentação] (a faixa em que as ondas quebram) abriga uma comunidade própria de peixes, e é natural perguntar: #emph[essa comunidade muda conforme a força da arrebentação?] Foi exatamente o que investigaram #cite(<felix2006>, form: "prose") no litoral do Paraná, num caso que virou referência de como o planejamento decide o destino da análise.

O desenho parecia robusto. Escolheram #strong[três praias] ao longo de um gradiente de exposição às ondas --- uma de energia baixa, uma média e uma alta --- e, durante #strong[doze meses], fizeram #strong[cinco arrastos] com rede picaré de 30 metros em cada praia. São cento e oitenta arrastos: uma montanha de dados, poder estatístico aparentemente de sobra.

Mas repare onde mora a cilada. Cada #strong[nível de energia] foi representado por #strong[uma única praia]: a energia baixa #emph[é] a Praia 1, a média #emph[é] a Praia 2, a alta #emph[é] a Praia 3. Energia e identidade da praia ficaram #strong[confundidas] --- grudadas, impossíveis de separar. Os cinco arrastos não são cinco réplicas do nível de energia; são #strong[subamostras] de uma praia só. No nível em que a pergunta de fato vive --- a energia da arrebentação ---, o número de unidades independentes é #strong[um]. É a pseudo-replicação de novo @hurlbert1984, só que agora no espaço, não no tanque.

A consequência é direta. Qualquer diferença entre as praias pode ser efeito da arrebentação, sim --- mas pode também ser granulometria, influência estuarina, presença de microhabitats ou qualquer atributo que aquelas três praias específicas não compartilham. O teste vai mesmo acusar diferença (ela existe), só que não consegue dizer #strong[de quê]. É como provar um único prato em três restaurantes e concluir algo sobre a culinária da cidade inteira: você comparou três pratos, não três cozinhas.

E não adianta coletar mais. Doze meses de uma praia continuam sendo uma praia; somar arrastos engorda a estimativa #emph[daquela] praia, não cria praias novas. O conserto não é mais esforço --- é esforço no #strong[lugar certo]. Para testar energia, cada nível precisa de #strong[várias praias independentes] (pelo menos três). Aí a variação natural entre praias de um mesmo nível deixa de ser um ruído ignorado e passa a ser a #strong[régua] contra a qual o efeito da energia é medido @underwood1997. Os arrastos seguem valiosos, mas no seu devido papel: subamostras que afinam a medida de cada praia, sem se passar por réplicas do fator.

Vale fixar o vocabulário, porque ele é a fonte de metade das confusões. A #strong[réplica] é a unidade independente que recebe o nível do fator --- aqui, a #strong[praia]. A #strong[subamostra] é cada coleta feita #emph[dentro] dessa unidade --- aqui, cada #strong[arrasto]. Os cinco arrastos de uma praia não são cinco praias: são cinco olhadas na mesma praia, que servem para descrevê-la com mais firmeza. Por isso, na prática, costuma-se #strong[tirar a média dos cinco arrastos] de cada praia e levar esse único valor representativo para a comparação entre os níveis de energia --- assim cada praia entra na análise como #strong[uma] unidade, que é exatamente o que ela é. A hierarquia fica: #strong[força da arrebentação] (fator) → #strong[praia] (réplica) → #strong[arrasto] (subamostra).

Fica a pergunta que desarma a armadilha --- a mesma de sempre, agora vestida de maré: #emph[o que, exatamente, recebeu o nível de energia de forma independente?] A praia. E é ela que você conta como réplica. O #ref(<fig-arrebentacao>, supplement: [Figura]) resume, passo a passo, o plano de coleta que transforma essa pergunta num desenho capaz de sustentar a resposta.

#figure([
#box(image("capitulos\\capitulo06/../../images/infografico_arrebentacao_planejamento.png", width: 80.0%))
], caption: figure.caption(
position: bottom, 
[
Planejamento amostral na zona de arrebentação. Para testar se a comunidade de peixes varia com a força das ondas, o gradiente de energia (baixa, média e alta) recebe, em cada nível, três praias independentes (P1--P9): as réplicas espaciais verdadeiras do fator. Em cada praia fazem-se vários arrastos de picaré padronizados, que são subamostras --- tira-se a média dos cinco arrastos para obter um único valor representativo por praia. A faixa inferior fixa a hierarquia amostral (força da arrebentação → praia → arrasto), e a coluna à direita resume os passos práticos da coleta. É esse desenho que separa o efeito da arrebentação da identidade de cada praia. Adaptado de #cite(<felix2006>, form: "prose").
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-arrebentacao>


== Planejamentos Experimentais
<planejamentos-experimentais>
Até agora apenas observamos. Mudemos de chave: e se quisermos saber se uma #strong[ração nova] faz o peixe crescer mais? Observar não basta --- precisamos #strong[intervir], dando a ração a uns e não a outros, e comparar. Essa é a essência do #strong[experimento], e é o que nos autoriza a falar em causa, não apenas em associação. Mas intervir tem regras; sem elas, você nunca saberá se mediu a ração ou o acaso.

Três princípios sustentam todo bom experimento. A #strong[repetição] (réplicas) nos dá uma medida do acaso, sem a qual não há como julgar se uma diferença é real ou sorte. A #strong[casualização] (sortear quem recebe cada tratamento) protege contra vieses que não controlamos --- aquele tanque que pega mais sol, aquele lote de peixes de outra origem. E o #strong[controle local] (blocos) isola fontes de variação conhecidas, como a posição no viveiro ou o dia da medição. Os delineamentos clássicos, que veremos a seguir, são apenas combinações inteligentes desses três princípios --- e a CatalyseR oferece cinco deles.

=== A armadilha da pseudo-replicação
<a-armadilha-da-pseudo-replicação>
Antes dos delineamentos, um aviso que vale por um capítulo inteiro.

#block[
#callout(
body: 
[
Réplica de verdade é a #strong[unidade experimental independente] --- aquela que recebeu o tratamento de forma autônoma. Se você aplica uma ração a #strong[um] tanque e depois pesa 50 peixes desse tanque, você #strong[não] tem 50 réplicas: tem uma só. Os 50 peixes dividem a mesma água, a mesma temperatura, a mesma história. Tratá-los como independentes é cometer #strong[pseudo-replicação] --- um erro tão comum quanto grave, que infla artificialmente o tamanho da amostra e fabrica significâncias falsas.

A pergunta que desarma a cilada é simples: #emph[o que, exatamente, recebeu o tratamento de forma independente?] A resposta é a sua unidade experimental --- e é ela que você conta como réplica.

]
, 
title: 
[
Conte réplicas, não subamostras
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
none
, 
body_background_color: 
white
)
]
=== DIC --- Inteiramente Casualizado
<dic-inteiramente-casualizado>
O #strong[Delineamento Inteiramente Casualizado] é o mais simples: os tratamentos são sorteados livremente entre as unidades, sem nenhuma restrição. Ele pede condições homogêneas --- um laboratório, ou um conjunto de gaiolas idênticas num mesmo tanque, onde nada além do tratamento distingue uma unidade da outra. É o desenho do experimento das rações iso-proteicas para bagres que analisaremos por ANOVA mais à frente.

Montar um DIC é sortear. Suponha quatro rações (A, B, C, D) e cinco gaiolas por ração:

#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("tratamentos ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("rep");#NormalTok("(");#FunctionTok("c");#NormalTok("(");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(", ");#StringTok("\"D\"");#NormalTok("), ");#AttributeTok("each =");#NormalTok(" ");#DecValTok("5");#NormalTok(")");],
[#NormalTok("plano_dic ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("gaiola =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("20");#NormalTok(", ");#AttributeTok("racao =");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(tratamentos))  ");#CommentTok("# casualização");],
[#FunctionTok("head");#NormalTok("(plano_dic)");],));
#block[
#Skylighting(([#NormalTok("  gaiola racao");],
[#NormalTok("1      1     A");],
[#NormalTok("2      2     B");],
[#NormalTok("3      3     C");],
[#NormalTok("4      4     C");],
[#NormalTok("5      5     C");],
[#NormalTok("6      6     C");],));
]
]
O #NormalTok("sample()"); embaralha as rações entre as gaiolas --- é a casualização em ação. A CatalyseR faz exatamente isso quando você escolhe #emph[DIC] no menu, e ainda desenha o #strong[croqui], o mapa do experimento que você leva para o campo:

#Skylighting(([#NormalTok("plano_dic");#SpecialCharTok("$");#NormalTok("col ");#OtherTok("<-");#NormalTok(" ((plano_dic");#SpecialCharTok("$");#NormalTok("gaiola ");#SpecialCharTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("%%");#NormalTok(" ");#DecValTok("5");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("plano_dic");#SpecialCharTok("$");#NormalTok("lin ");#OtherTok("<-");#NormalTok(" ((plano_dic");#SpecialCharTok("$");#NormalTok("gaiola ");#SpecialCharTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("%/%");#NormalTok(" ");#DecValTok("5");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#DecValTok("1");],
[],
[#FunctionTok("ggplot");#NormalTok("(plano_dic, ");#FunctionTok("aes");#NormalTok("(col, lin, ");#AttributeTok("fill =");#NormalTok(" racao)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_tile");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(", ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("1.2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_text");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("label =");#NormalTok(" racao), ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(", ");#AttributeTok("fontface =");#NormalTok(" ");#StringTok("\"bold\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"NAVY\"");#NormalTok(",");#StringTok("\"TEAL\"");#NormalTok(",");#StringTok("\"AMBER\"");#NormalTok(",");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_y_reverse");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"Ração\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("axis.text =");#NormalTok(" ");#FunctionTok("element_blank");#NormalTok("(), ");#AttributeTok("panel.grid =");#NormalTok(" ");#FunctionTok("element_blank");#NormalTok("())");],));
#figure([
#box(image("capitulos\\capitulo06/planejando_sua_pesquisa_files/figure-typst/dic-croqui-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Croqui de um DIC com quatro rações e cinco repetições: as 20 gaiolas dispostas numa grade, com o tratamento sorteado para cada uma.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)


=== DBC --- Blocos Casualizados
<dbc-blocos-casualizados>
E quando as condições #strong[não] são homogêneas? Imagine um viveiro comprido em que a água corre mais fria numa ponta do que na outra. Se você casualizar sem cuidado, a temperatura vira um carona clandestino na comparação das rações. O #strong[Delineamento em Blocos Casualizados] resolve isso agrupando as unidades em #strong[blocos] homogêneos --- cada faixa do viveiro é um bloco --- e sorteando #strong[todos] os tratamentos dentro de cada bloco. Assim, a variação entre blocos é isolada e tirada do caminho.

#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("trats ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(")");],
[#NormalTok("plano_dbc ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("do.call");#NormalTok("(rbind, ");#FunctionTok("lapply");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#DecValTok("4");#NormalTok(", ");#ControlFlowTok("function");#NormalTok("(b) {");],
[#NormalTok("  ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("bloco =");#NormalTok(" b, ");#AttributeTok("posicao =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("3");#NormalTok(", ");#AttributeTok("racao =");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(trats))  ");#CommentTok("# sorteio dentro do bloco");],
[#NormalTok("}))");],
[#FunctionTok("head");#NormalTok("(plano_dbc, ");#DecValTok("6");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("  bloco posicao racao");],
[#NormalTok("1     1       1     A");],
[#NormalTok("2     1       2     C");],
[#NormalTok("3     1       3     B");],
[#NormalTok("4     2       1     B");],
[#NormalTok("5     2       2     A");],
[#NormalTok("6     2       3     C");],));
]
]
Repare que o sorteio acontece #strong[dentro] de cada bloco: todo bloco recebe A, B e C, em ordem própria. É essa restrição que separa o DBC do DIC.

=== DQL --- Quadrado Latino
<dql-quadrado-latino>
Às vezes não há uma, mas #strong[duas] fontes de variação a controlar --- por exemplo, a linha e a coluna de uma bancada de aquários, onde a luz varia num sentido e a temperatura no outro. O #strong[Delineamento em Quadrado Latino] dá conta das duas ao mesmo tempo: dispõe os tratamentos de modo que cada um apareça #strong[uma vez em cada linha e uma vez em cada coluna].

#block[
#Skylighting(([#NormalTok("trats ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"A\"");#NormalTok(", ");#StringTok("\"B\"");#NormalTok(", ");#StringTok("\"C\"");#NormalTok(", ");#StringTok("\"D\"");#NormalTok(")");],
[#NormalTok("ql ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("outer");#NormalTok("(");#DecValTok("0");#SpecialCharTok(":");#DecValTok("3");#NormalTok(", ");#DecValTok("0");#SpecialCharTok(":");#DecValTok("3");#NormalTok(", ");#ControlFlowTok("function");#NormalTok("(i, j) trats[((i ");#SpecialCharTok("+");#NormalTok(" j) ");#SpecialCharTok("%%");#NormalTok(" ");#DecValTok("4");#NormalTok(") ");#SpecialCharTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("])");],
[#NormalTok("ql");],));
#block[
#Skylighting(([#NormalTok("     [,1] [,2] [,3] [,4]");],
[#NormalTok("[1,] \"A\"  \"B\"  \"C\"  \"D\" ");],
[#NormalTok("[2,] \"B\"  \"C\"  \"D\"  \"A\" ");],
[#NormalTok("[3,] \"C\"  \"D\"  \"A\"  \"B\" ");],
[#NormalTok("[4,] \"D\"  \"A\"  \"B\"  \"C\" ");],));
]
]
Cada letra ocupa cada linha e cada coluna uma única vez --- luz e temperatura ficam, ambas, equilibradas entre os tratamentos. A restrição do método é geométrica: o número de tratamentos tem de ser igual ao de linhas e ao de colunas.

=== Fatorial
<fatorial>
Até aqui variamos um fator de cada vez. Mas e se a #strong[alimentação] e a quantidade de #strong[abrigo] importarem juntas --- e, pior, se o ganho do suplemento na ração mudar conforme o abrigo disponível? Estudá-los em experimentos separados nunca revelaria isso. O #strong[delineamento fatorial] cruza os fatores e testa todas as combinações de uma vez, o que permite enxergar não só o efeito de cada um, mas a #strong[interação] entre eles: o caso em que o efeito de um depende do nível do outro.

A #ref(<fig-fatorial>, supplement: [Figura]) mostra um exemplo concreto. Cruzamos a #strong[alimentação] (Fator A: ração padrão, $A_0$, ou com suplemento, $A_1$ --- dois níveis) com a #strong[vegetação/abrigo] (Fator V: baixa, média ou alta --- três níveis). São $2 times 3 = 6$ combinações, e cada aquário recebe uma delas. Repare que o desenho é, ao mesmo tempo, #strong[fatorial e em blocos]: as seis combinações aparecem uma vez em cada bloco, sorteadas dentro dele, e os cinco blocos controlam variações do ambiente --- posição na estante, luminosidade --- como vimos no DBC. Cinco blocos × seis combinações dão trinta aquários, e cada aquário é uma unidade experimental.

#figure([
#box(image("capitulos\\capitulo06/../../images/delineamento_fatorial.png", width: 90.0%))
], caption: figure.caption(
position: bottom, 
[
Delineamento fatorial $2 times 3$ em cinco blocos. O #strong[Fator A] (alimentação: $A_0$ ração padrão, $A_1$ ração com suplemento) cruza com o #strong[Fator V] (vegetação/abrigo: $V_1$ baixa, $V_2$ média, $V_3$ alta), gerando seis combinações. Em cada bloco, as seis combinações aparecem uma única vez, em ordem sorteada; os blocos controlam variações do ambiente (posição, luminosidade). Cada aquário é uma unidade experimental --- cinco blocos × seis combinações = trinta aquários.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-fatorial>


Montar esse plano é cruzar os fatores e sortear as combinações dentro de cada bloco:

#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("combinacoes ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("expand.grid");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("alimentacao =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"A0\"");#NormalTok(", ");#StringTok("\"A1\"");#NormalTok("),               ");#CommentTok("# padrão / com suplemento");],
[#NormalTok("  ");#AttributeTok("vegetacao   =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"V1\"");#NormalTok(", ");#StringTok("\"V2\"");#NormalTok(", ");#StringTok("\"V3\"");#NormalTok(")          ");#CommentTok("# abrigo baixo / médio / alto");],
[#NormalTok(")                                            ");#CommentTok("# 2 x 3 = 6 combinações");],
[],
[#NormalTok("plano_fat ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("do.call");#NormalTok("(rbind, ");#FunctionTok("lapply");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#DecValTok("5");#NormalTok(", ");#ControlFlowTok("function");#NormalTok("(bloco) {");],
[#NormalTok("  ordem ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(");#FunctionTok("nrow");#NormalTok("(combinacoes))         ");#CommentTok("# sorteio dentro do bloco");],
[#NormalTok("  ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("bloco =");#NormalTok(" bloco, ");#AttributeTok("aquario =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#DecValTok("6");#NormalTok(",");],
[#NormalTok("             combinacoes[ordem, ], ");#AttributeTok("row.names =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[#NormalTok("}))");],
[#FunctionTok("head");#NormalTok("(plano_fat)");],));
#block[
#Skylighting(([#NormalTok("  bloco aquario alimentacao vegetacao");],
[#NormalTok("1     1       1          A0        V3");],
[#NormalTok("2     1       2          A0        V1");],
[#NormalTok("3     1       3          A1        V3");],
[#NormalTok("4     1       4          A1        V1");],
[#NormalTok("5     1       5          A1        V2");],
[#NormalTok("6     1       6          A0        V2");],));
]
]
O #NormalTok("expand.grid()"); gera as seis combinações; o #NormalTok("sample()"); as embaralha dentro de cada bloco. A interação é a verdadeira recompensa do fatorial --- é ela que responde perguntas do tipo "o suplemento na ração só compensa quando há bastante abrigo?".

=== Parcelas Subdivididas (Split-Plot)
<parcelas-subdivididas-split-plot>
Chegamos ao delineamento mais sofisticado da lista --- e ao que mais se presta a confusão. Ele aparece quando um dos fatores só pode ser aplicado a uma área grande, e o outro, a subdivisões dela. Pense em #strong[temperatura da água], que vale para um tanque inteiro, combinada com #strong[linhagem do peixe], que você consegue separar em compartimentos dentro do tanque. A temperatura vai na #strong[parcela principal]\; a linhagem, nas #strong[subparcelas].

A consequência é que há #strong[dois sorteios], em dois níveis. Primeiro, dentro de cada bloco, sorteiam-se os níveis do fator principal entre as parcelas grandes. Depois, dentro de cada parcela grande, sorteiam-se os níveis do fator subdividido entre as subparcelas. A #ref(<fig-split-plot>, supplement: [Figura]) mostra essa aleatorização em dois estágios.

#figure([
#box(image("capitulos\\capitulo06/../../images/Parcelas-subdivididas.png", width: 70.0%))
], caption: figure.caption(
position: bottom, 
[
Delineamento em parcelas subdivididas (split-plot) com três blocos. Em cada bloco, os níveis do #strong[Fator A] (parcelas principais, A1--A3) são sorteados primeiro; dentro de cada parcela principal, os níveis do #strong[Fator B] (subparcelas, B1--B4) são sorteados em seguida. São, portanto, dois estágios de aleatorização --- a origem das duas fontes de erro que a análise precisa respeitar.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-split-plot>


Esse arranjo se monta sorteando em duas etapas:

#block[
#Skylighting(([#FunctionTok("set.seed");#NormalTok("(");#DecValTok("2026");#NormalTok(")");],
[#NormalTok("A ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"A1\"");#NormalTok(", ");#StringTok("\"A2\"");#NormalTok(", ");#StringTok("\"A3\"");#NormalTok(")            ");#CommentTok("# fator principal (parcela): ex. temperatura");],
[#NormalTok("B ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"B1\"");#NormalTok(", ");#StringTok("\"B2\"");#NormalTok(", ");#StringTok("\"B3\"");#NormalTok(", ");#StringTok("\"B4\"");#NormalTok(")      ");#CommentTok("# fator subdividido (subparcela): ex. linhagem");],
[],
[#NormalTok("plano_sp ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("do.call");#NormalTok("(rbind, ");#FunctionTok("lapply");#NormalTok("(");#DecValTok("1");#SpecialCharTok(":");#DecValTok("3");#NormalTok(", ");#ControlFlowTok("function");#NormalTok("(bloco) {");],
[#NormalTok("  ordem_A ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(A)                                   ");#CommentTok("# 1o sorteio: parcelas no bloco");],
[#NormalTok("  ");#FunctionTok("do.call");#NormalTok("(rbind, ");#FunctionTok("lapply");#NormalTok("(");#FunctionTok("seq_along");#NormalTok("(ordem_A), ");#ControlFlowTok("function");#NormalTok("(p) {");],
[#NormalTok("    ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("bloco =");#NormalTok(" bloco, ");#AttributeTok("parcela =");#NormalTok(" p, ");#AttributeTok("fator_A =");#NormalTok(" ordem_A[p],");],
[#NormalTok("               ");#AttributeTok("sub =");#NormalTok(" ");#DecValTok("1");#SpecialCharTok(":");#FunctionTok("length");#NormalTok("(B), ");#AttributeTok("fator_B =");#NormalTok(" ");#FunctionTok("sample");#NormalTok("(B))   ");#CommentTok("# 2o sorteio: subparcelas");],
[#NormalTok("  }))");],
[#NormalTok("}))");],
[#FunctionTok("head");#NormalTok("(plano_sp, ");#DecValTok("8");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("  bloco parcela fator_A sub fator_B");],
[#NormalTok("1     1       1      A1   1      B2");],
[#NormalTok("2     1       1      A1   2      B1");],
[#NormalTok("3     1       1      A1   3      B3");],
[#NormalTok("4     1       1      A1   4      B4");],
[#NormalTok("5     1       2      A3   1      B4");],
[#NormalTok("6     1       2      A3   2      B1");],
[#NormalTok("7     1       2      A3   3      B3");],
[#NormalTok("8     1       2      A3   4      B2");],));
]
]
O detalhe que #strong[não] pode ser ignorado é a contabilidade do erro. Por haver dois níveis de sorteio, há #strong[duas fontes de erro]: o fator principal é julgado contra o erro entre parcelas; o fator subdividido e a interação, contra o erro entre subparcelas. Tratar tudo como um experimento simples --- o engano clássico --- leva a testar o fator principal com a régua errada. É um parente próximo da pseudo-replicação, e o motivo de o split-plot exigir uma análise com a estrutura certa.

=== Estudo de caso experimental
<estudo-de-caso-experimental>
Um exemplo aterrissa todos esses princípios. No experimento das rações iso-proteicas para bagres, quatro rações (A a D) são distribuídas ao acaso entre gaiolas-rede idênticas num mesmo tanque, com cinco réplicas cada --- um #strong[DIC] de manual. As gaiolas são idênticas (condições homogêneas), o sorteio protege contra vieses, e as cinco réplicas medem o acaso. No fim, pesam-se os peixes e comparam-se as médias.

E como se comparam quatro médias de uma vez? Com a #strong[ANOVA], que veremos na unidade de inferência. Eis a grande recompensa de planejar direito: um experimento bem desenhado já nasce pedindo a análise certa. O delineamento aqui escolhido entrega, de bandeja, a ANOVA que aplicaremos adiante. O conjunto #NormalTok("isoproteica_bagre");, do #NormalTok("EAPADados");, guarda esses dados para a nossa prática.

== Do mouse ao código: planejar na CatalyseR
<do-mouse-ao-código-planejar-na-catalyser>
Tudo o que percorremos neste capítulo cabe num só lugar da IDE: o menu #strong[Planejando sua Pesquisa], com seus dois submenus --- #emph[Planejamentos Observacionais] e #emph[Planejamentos Experimentais]. Você escolhe o método (uma das amostragens ou um dos delineamentos), informa os níveis, repetições e blocos, e a CatalyseR sorteia o plano e desenha o croqui na tela. Nada de digitar #NormalTok("sample()"); na mão, a menos que você queira.

E aí entra a ponte que dá identidade ao ecossistema: ao clicar em #strong[exportar], a interface gera um #strong[Projeto R (.zip)] com o script de sorteio e um relatório Quarto já preenchido --- os mesmos templates #NormalTok("relatorio_sampling.qmd"); e #NormalTok("relatorio_experimental_design.qmd");. Você sai da tela com o plano de coleta documentado e reproduzível, pronto para levar a campo. É o "do mouse ao código" aplicado ao começo de tudo: a IDE planeja com você apontando e clicando, e te devolve o código que registra e reproduz cada decisão.

#block[
#callout(
body: 
[
Antes do primeiro número vem a decisão que comanda todas as outras: #strong[planejar a coleta é escolher o teste]. O planejamento tem dois ramos. No #strong[observacional], não intervimos --- apenas sorteamos quem observar, com #strong[amostragem aleatória simples] (todos com a mesma chance), #strong[estratificada proporcional] (cada subgrupo na medida do seu peso) ou #strong[sistemática] (ponto de partida sorteado e passo fixo). No #strong[experimental], intervimos para falar de causa, sob três princípios --- #strong[repetição], #strong[casualização] e #strong[controle local] ---, e fugindo da #strong[pseudo-replicação], que confunde subamostras com réplicas. Os delineamentos combinam esses princípios: #strong[DIC] para condições homogêneas, #strong[DBC] para isolar uma fonte de variação, #strong[DQL] para isolar duas, #strong[fatorial] para estudar fatores e suas interações, e #strong[parcelas subdivididas] quando há dois níveis de aplicação --- e, com eles, duas fontes de erro. Todo estudo bem planejado já nasce pedindo a análise certa.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Liste as variáveis do estudo do camarão e classifique cada uma como nominal, ordinal, discreta ou contínua. Quais permitiriam uma comparação de médias? Quais, uma tabela de contingência?
+ Sorteie, por AAS, cinco dias de coleta entre vinte possíveis. Mude a semente (#NormalTok("set.seed");) e observe como o sorteio muda.
+ Você tem três áreas com 600, 300 e 100 indivíduos e quer uma amostra total de 40. Calcule, em R, a alocação proporcional por estrato.
+ Monte, em R, o plano de um DIC com casualização para três dietas em doze tanques.
+ Explique, com suas palavras, por que pesar trinta peixes de um único tanque tratado não gera trinta réplicas.
+ Num split-plot que cruza temperatura da água e linhagem do peixe, qual fator você poria na parcela principal e qual na subparcela? Por quê?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Preparando os dados: do caos ao #emph[tidy]
<preparando-os-dados-do-caos-ao-tidy>
Ou: como transformar uma planilha larga e teimosa em dados prontos para analisar

\
#block[
#callout(
body: 
[
Você baixou a planilha do desembarque pesqueiro e abriu cheio de esperança. Aí veio o balde de água fria: dezenas de colunas com nomes como #NormalTok("2021 - Captura_t");, #NormalTok("2021 - Receita_mil");, #NormalTok("2022 - Captura_t");… uma coluna nova para cada ano e cada medida. Você quer só fazer um gráfico da captura ao longo do tempo, mas o R não entende essa bagunça. E agora?

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
A boa notícia é que essa dor tem cura, e a cura é rápida. No fim deste capítulo, aquela planilha teimosa vai virar um conjunto de dados organizado --- e a receita que fez isso caberá em três linhas de código que você pode guardar e reusar todo ano. Melhor: você vai montar essa receita #strong[no mouse], dentro da CatalyseR, e sair com o script #NormalTok(".R"); pronto.

Antes de qualquer teste, antes de qualquer gráfico bonito, existe uma etapa que quase ninguém conta nos livros: #strong[arrumar os dados]. É a parte silenciosa do trabalho, a que dá menos glória e toma mais tempo. Mas é também onde as boas análises começam. Uma planilha bem arrumada chega #strong[pronta] para o teste; uma planilha bagunçada contamina tudo que vem depois. Este capítulo é sobre transformar a primeira na segunda, com método.

O preparo completo tem cinco passos, sempre nesta ordem: #strong[importar → arrumar → filtrar → tipar → recodificar] --- a mesma sequência do menu #emph[Preparando Dados] da CatalyseR. Os extremos você já conhece do Capítulo 3: importar os dados e dar-lhes os tipos certos. Aqui a gente foca no #strong[coração]: #emph[arrumar], ou seja, dar aos dados a forma que a análise espera --- e na ferramenta que faz isso brilhar, as #strong[expressões regulares] (regex). A #ref(<fig-preparo>, supplement: [Figura]) resume o percurso: da planilha larga e teimosa até os dados #emph[tidy], prontos para analisar.

#figure([
#box(image("capitulos\\capitulo05/../../images/preparo_dados_tidy.png", width: 85.0%))
], caption: figure.caption(
position: bottom, 
[
Da planilha larga e bagunçada aos dados #emph[tidy]: empilhar tira o ano/medida do cabeçalho, alargar deixa cada medida em sua coluna, e separar quebra uma coluna composta. Fonte: elaborado pelo autor.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-preparo>


== Os dados de treino
<os-dados-de-treino>
Para aprender a arrumar, nada de dados perfeitos. Precisamos de dados com os defeitos típicos do mundo real --- só que pequenos e previsíveis, para você conseguir seguir cada passo com os olhos. Por isso o #NormalTok("EAPADados"); traz dois conjuntos com o prefixo #NormalTok("treino_");, sintéticos e propositalmente "mal-arrumados", cada um treinando um tipo de arrumação.

O primeiro, #NormalTok("treino_desembarque");, imita um relatório de produção pesqueira em #strong[formato largo]: cada ano vira duas colunas (captura e receita).

#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(treino_desembarque)");],));
#block[
#Skylighting(([#NormalTok("Rows: 12");],
[#NormalTok("Columns: 8");],
[#NormalTok("$ Porto                <chr> \"Bragança\", \"Bragança\", \"Bragança\", \"Vigia\", \"Vig…");],
[#NormalTok("$ Especie              <chr> \"Pargo\", \"Serra\", \"Pescada\", \"Pargo\", \"Serra\", \"P…");],
[#NormalTok("$ `2021 - Captura_t`   <dbl> 172.6, 150.2, 101.0, 89.1, 61.5, 113.6, 46.8, 111…");],
[#NormalTok("$ `2021 - Receita_mil` <dbl> 2449.3, 1795.4, 1404.8, 1014.1, 701.6, 1255.5, 49…");],
[#NormalTok("$ `2022 - Captura_t`   <dbl> 184.8, 145.6, 89.0, 69.6, 58.8, 147.3, 53.0, 96.9…");],
[#NormalTok("$ `2022 - Receita_mil` <dbl> 1843.7, 1533.2, 1080.9, 1092.8, 547.1, 2238.7, 50…");],
[#NormalTok("$ `2023 - Captura_t`   <dbl> 171.8, 183.9, 83.3, 76.1, 64.4, 130.9, 51.6, 122.…");],
[#NormalTok("$ `2023 - Receita_mil` <dbl> 2436.9, 1689.3, 1256.6, 734.3, 635.9, 1354.3, 500…");],));
]
]
Repare no problema: o #strong[ano] e a #strong[medida] estão escondidos no #emph[nome] da coluna, não nos dados. Para o R, #NormalTok("2021 - Captura_t"); é apenas um rótulo --- ele não sabe que ali dentro moram um ano (2021) e uma variável (captura em toneladas). Enquanto essa informação estiver presa no cabeçalho, você não consegue filtrar por ano nem plotar a captura contra o tempo.

O segundo, #NormalTok("treino_coletas");, tem o defeito oposto: a informação está #strong[espremida dentro de uma célula].

#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(treino_coletas)");],));
#block[
#Skylighting(([#NormalTok("Rows: 15");],
[#NormalTok("Columns: 5");],
[#NormalTok("$ id              <int> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15");],
[#NormalTok("$ codigo_coleta   <chr> \"SERRA-2023-AUG\", \"PESCADA-2021-AUG\", \"PESCADA-2023-AU…");],
[#NormalTok("$ estacao_periodo <chr> \"E04_Chuvosa\", \"E01_Seca\", \"E01_Chuvosa\", \"E01_Seca\", …");],
[#NormalTok("$ comprimento_cm  <dbl> 26.1, 23.7, 32.1, 43.2, 23.9, 50.2, 38.0, 18.7, 21.2, …");],
[#NormalTok("$ peso_g          <dbl> 213.2, 115.0, 396.4, 818.1, 109.4, 1163.1, 609.9, 76.6…");],));
]
]
A coluna #NormalTok("codigo_coleta"); guarda três coisas grudadas --- espécie, ano e porto --- num código como #NormalTok("PARGO-2023-BRA");. É prático para quem anota no campo, mas inútil para analisar: você não consegue agrupar por espécie nem comparar anos enquanto tudo estiver colado.

Dois defeitos, duas soluções. Vamos a elas --- mas primeiro, à ideia que guia todas.

== Largo, longo e o princípio #emph[tidy]
<largo-longo-e-o-princípio-tidy>
No Capítulo 3 você conheceu a régua dos dados #emph[tidy] (arrumados): cada variável em uma coluna, cada observação em uma linha, um valor por célula. É a organização "chata de propósito" que deixa somar, filtrar e comparar sem sofrimento --- e que o #NormalTok("ggplot2");, o #NormalTok("dplyr"); e a CatalyseR esperam receber.

Os dois defeitos dos nossos conjuntos de treino são, no fundo, violações dessa régua. No #NormalTok("treino_desembarque");, uma mesma variável (a captura) está espalhada por várias colunas --- uma para cada ano. No #NormalTok("treino_coletas");, várias variáveis (espécie, ano, porto) estão amontoadas numa célula só. E é justamente aqui que este capítulo se separa do anterior: lá você aprendeu a #strong[limpar] os dados (padronizar nomes, acertar tipos, caçar espaços fantasmas); aqui você aprende a #strong[reformatá-los] --- mudar a forma da tabela inteira.

Para reformatar, um par de palavras novo. Dados em formato #strong[largo] (#emph[wide]) têm muitas colunas e poucas linhas --- uma coluna por ano, por exemplo. Dados em formato #strong[longo] (#emph[long]) empilham essa informação: menos colunas, mais linhas, uma linha por combinação. Arrumar dados de pesquisa é, quase sempre, ir do largo para o longo --- e, às vezes, voltar um pouco. É esse vaivém que os próximos passos ensinam. E vale a intuição que guia tudo: #strong[arrumar já é preparar a análise] --- com os dados #emph[tidy], o gráfico e o teste vêm quase de graça.

== Do mouse ao código: os cinco passos
<do-mouse-ao-código-os-cinco-passos>
Agora a parte prática. Vamos percorrer os cinco passos na CatalyseR e ver o R que corresponde a cada clique.

=== Importar
<importar>
Este passo você já domina do Capítulo 3: #NormalTok("read_csv()");, #NormalTok("read_excel()"); ou #NormalTok("rio::import()");, sempre com #NormalTok("here::here()"); para o caminho não quebrar. Na CatalyseR, é o menu #emph[Importação e Visualização]. Como aqui os dados já chegam prontos do #NormalTok("EAPADados"); --- #NormalTok("data(treino_desembarque)"); ---, seguimos direto para a parte nova. Só um lembrete que economiza horas: se a planilha já chega #emph[tidy] da origem, os passos seguintes quase somem.

=== Empilhar: do largo para o longo
<empilhar-do-largo-para-o-longo>
Aqui está o coração do capítulo. Empilhar é pegar aquele monte de colunas de ano e transformá-las em duas colunas: uma que diz #strong[qual] ano/medida, outra que guarda o #strong[valor]. A função que faz isso é #NormalTok("pivot_longer()");, e ela tem um truque elegante: consegue, no mesmo passo, #strong[extrair] o ano e a medida de dentro do nome da coluna.

#block[
#Skylighting(([#NormalTok("longo ");#OtherTok("<-");#NormalTok(" treino_desembarque ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("cols =");#NormalTok(" ");#FunctionTok("matches");#NormalTok("(");#StringTok("\"^[0-9]{4} - \"");#NormalTok("),        ");#CommentTok("# as colunas que começam com um ano");],
[#NormalTok("    ");#AttributeTok("names_to =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"ano\"");#NormalTok(", ");#StringTok("\"metrica\"");#NormalTok("),         ");#CommentTok("# dois pedaços a extrair do nome");],
[#NormalTok("    ");#AttributeTok("names_pattern =");#NormalTok(" ");#StringTok("\"^([0-9]{4}) - (.*)$\"");#NormalTok(",  ");#CommentTok("# a regra que separa ano e medida");],
[#NormalTok("    ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"valor\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("values_transform =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("valor =");#NormalTok(" as.numeric)");],
[#NormalTok("  )");],
[],
[#FunctionTok("head");#NormalTok("(longo)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  Porto    Especie ano   metrica     valor");],
[#NormalTok("  <chr>    <chr>   <chr> <chr>       <dbl>");],
[#NormalTok("1 Bragança Pargo   2021  Captura_t    173.");],
[#NormalTok("2 Bragança Pargo   2021  Receita_mil 2449.");],
[#NormalTok("3 Bragança Pargo   2022  Captura_t    185.");],
[#NormalTok("4 Bragança Pargo   2022  Receita_mil 1844.");],
[#NormalTok("5 Bragança Pargo   2023  Captura_t    172.");],
[#NormalTok("6 Bragança Pargo   2023  Receita_mil 2437.");],));
]
]
Olhe o que aconteceu: o #NormalTok("ano"); e a #NormalTok("metrica");, antes presos no cabeçalho, agora são colunas de verdade. Aquele #NormalTok("names_pattern"); é uma #strong[expressão regular] (regex) --- o padrão que ensina o R a fatiar o nome da coluna. Não se assuste com ela; a próxima seção a destrincha. Por ora, guarde a intuição: cada pedaço entre parênteses #NormalTok("( )"); no padrão vira uma coluna nova. Dois parênteses, dois nomes (#NormalTok("ano"); e #NormalTok("metrica");).

Na CatalyseR, esse passo é o menu #emph[Empilhar Colunas (Largo → Longo)]: você clica em "Detectar automaticamente" para marcar as colunas de ano, escolhe o padrão de extração numa lista e vê o resultado na hora --- sem escrever a regex à mão.

=== Alargar: uma medida em cada coluna
<alargar-uma-medida-em-cada-coluna>
O formato longo já é analisável, mas às vezes queremos um meio-termo: uma linha por porto-espécie-ano, com a #strong[captura] e a #strong[receita] lado a lado, em colunas separadas. Isso é #emph[alargar] --- o caminho de volta, com #NormalTok("pivot_wider()");:

#block[
#Skylighting(([#NormalTok("tidy_final ");#OtherTok("<-");#NormalTok(" longo ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_wider");#NormalTok("(");#AttributeTok("names_from =");#NormalTok(" metrica, ");#AttributeTok("values_from =");#NormalTok(" valor)");],
[],
[#FunctionTok("head");#NormalTok("(tidy_final)");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 6 × 5");],
[#NormalTok("  Porto    Especie ano   Captura_t Receita_mil");],
[#NormalTok("  <chr>    <chr>   <chr>     <dbl>       <dbl>");],
[#NormalTok("1 Bragança Pargo   2021       173.       2449.");],
[#NormalTok("2 Bragança Pargo   2022       185.       1844.");],
[#NormalTok("3 Bragança Pargo   2023       172.       2437.");],
[#NormalTok("4 Bragança Serra   2021       150.       1795.");],
[#NormalTok("5 Bragança Serra   2022       146.       1533.");],
[#NormalTok("6 Bragança Serra   2023       184.       1689.");],));
]
]
Agora sim: cada linha é uma observação (porto, espécie, ano) e cada medida tem sua coluna. Este é o formato #emph[tidy] que a maioria das análises espera. Repare que empilhar e alargar são movimentos opostos e complementares --- empilhamos para extrair o que estava no cabeçalho, e alargamos para deixar cada medida em sua coluna.

=== Separar: quebrar uma coluna composta
<separar-quebrar-uma-coluna-composta>
E quando o problema não está no cabeçalho, mas #strong[dentro] de uma célula? É o caso do #NormalTok("treino_coletas");, com aquele #NormalTok("codigo_coleta"); no formato #NormalTok("PARGO-2023-BRA");. Aqui não há o que empilhar --- só o que #strong[separar]. A função #NormalTok("extract()"); quebra uma coluna em várias usando a mesma ideia de regex com parênteses:

#block[
#Skylighting(([#NormalTok("coletas ");#OtherTok("<-");#NormalTok(" treino_coletas ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("extract");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("col =");#NormalTok(" codigo_coleta,");],
[#NormalTok("    ");#AttributeTok("into =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"especie\"");#NormalTok(", ");#StringTok("\"ano\"");#NormalTok(", ");#StringTok("\"porto\"");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("regex =");#NormalTok(" ");#StringTok("\"^(.*)-([0-9]{4})-(.*)$\"");#NormalTok(",   ");#CommentTok("# três pedaços: espécie, ano, porto");],
[#NormalTok("    ");#AttributeTok("remove =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok("                       ");#CommentTok("# mantém o código original, por segurança");],
[#NormalTok("  )");],
[],
[#FunctionTok("head");#NormalTok("(coletas)");],));
#block[
#Skylighting(([#NormalTok("  id    codigo_coleta especie  ano porto estacao_periodo comprimento_cm peso_g");],
[#NormalTok("1  1   SERRA-2023-AUG   SERRA 2023   AUG     E04_Chuvosa           26.1  213.2");],
[#NormalTok("2  2 PESCADA-2021-AUG PESCADA 2021   AUG        E01_Seca           23.7  115.0");],
[#NormalTok("3  3 PESCADA-2023-AUG PESCADA 2023   AUG     E01_Chuvosa           32.1  396.4");],
[#NormalTok("4  4 PESCADA-2023-BEL PESCADA 2023   BEL        E01_Seca           43.2  818.1");],
[#NormalTok("5  5   SERRA-2021-BEL   SERRA 2021   BEL     E03_Chuvosa           23.9  109.4");],
[#NormalTok("6  6 PESCADA-2023-BEL PESCADA 2023   BEL        E02_Seca           50.2 1163.1");],));
]
]
Três parênteses no padrão, três colunas novas. A coluna #NormalTok("estacao_periodo");, com valores como #NormalTok("E03_Seca");, pediria uma quebra ainda mais simples (#NormalTok("^(.*)_(.*)$");). Na CatalyseR, este é o menu #emph[Separar Coluna em Colunas]: você escolhe a coluna, define o padrão e cada grupo vira uma coluna --- de novo, sem digitar código.

=== Filtrar e recodificar (e um lembrete de tipagem)
<filtrar-e-recodificar-e-um-lembrete-de-tipagem>
Com os dados empilhados e separados, faltam os retoques finais. #strong[Filtrar] é ficar só com o que interessa --- os anos mais recentes, uma espécie específica. #strong[Recodificar] é agrupar ou renomear níveis: juntar portos vizinhos numa região, padronizar grafias. E a #strong[tipagem] --- dizer ao R que #NormalTok("ano"); é número e #NormalTok("Especie"); é fator --- você já viu a fundo no Capítulo 3; aqui ela entra só como acabamento.

#block[
#Skylighting(([#NormalTok("analise ");#OtherTok("<-");#NormalTok(" tidy_final ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(ano ");#SpecialCharTok(">=");#NormalTok(" ");#StringTok("\"2022\"");#NormalTok(") ");#SpecialCharTok("|>");#NormalTok("                          ");#CommentTok("# filtrar: só anos recentes");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("ano     =");#NormalTok(" ");#FunctionTok("as.integer");#NormalTok("(ano),                       ");#CommentTok("# tipar (revisão do Cap. 3)");],
[#NormalTok("    ");#AttributeTok("Especie =");#NormalTok(" ");#FunctionTok("factor");#NormalTok("(Especie)");],
[#NormalTok("  )");],
[],
[#FunctionTok("glimpse");#NormalTok("(analise)");],));
#block[
#Skylighting(([#NormalTok("Rows: 24");],
[#NormalTok("Columns: 5");],
[#NormalTok("$ Porto       <chr> \"Bragança\", \"Bragança\", \"Bragança\", \"Bragança\", \"Bragança\"…");],
[#NormalTok("$ Especie     <fct> Pargo, Pargo, Serra, Serra, Pescada, Pescada, Pargo, Pargo…");],
[#NormalTok("$ ano         <int> 2022, 2023, 2022, 2023, 2022, 2023, 2022, 2023, 2022, 2023…");],
[#NormalTok("$ Captura_t   <dbl> 184.8, 171.8, 145.6, 183.9, 89.0, 83.3, 69.6, 76.1, 58.8, …");],
[#NormalTok("$ Receita_mil <dbl> 1843.7, 2436.9, 1533.2, 1689.3, 1080.9, 1256.6, 1092.8, 73…");],));
]
]
Na CatalyseR, tudo isso vive na tela de importação --- os filtros de faixa e de nível, a tipagem de cada coluna e o botão #emph[Renomear Colunas] para trocar #NormalTok("2021 - Captura_t"); por algo limpo como #NormalTok("captura_t");. Cada ajuste no mouse entra no script.

=== E o código sai pronto
<e-o-código-sai-pronto>
Este é o ponto que amarra o capítulo à filosofia do livro. A cada passo que você faz no mouse, a CatalyseR #strong[monta o script #NormalTok(".R"); correspondente] e o entrega para download. Você arruma clicando, entende a lógica, e leva para casa um código reproduzível --- que roda igual no ano que vem, com a planilha nova, sem repetir o trabalho manual. É o "do mouse ao código" na etapa mais ingrata do fluxo, justamente a que mais se beneficia de virar código.

== Regex sem susto
<regex-sem-susto>
Aquele #NormalTok("names_pattern"); e o #NormalTok("regex"); do #NormalTok("extract()"); assustam à primeira vista, mas a lógica é simples. Uma #strong[expressão regular] (regex) é só um padrão que descreve um texto, lido da esquerda para a direita. Você não precisa decorar tudo --- precisa reconhecer meia dúzia de peças.

#Skylighting(([#NormalTok("regex_guia ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");],
[#NormalTok("  Peça ");#OtherTok("=");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"^\"");#NormalTok(", ");#StringTok("\"$\"");#NormalTok(", ");#StringTok("\"");#SpecialCharTok("\\\\");#StringTok("d\"");#NormalTok(", ");#StringTok("\"{4}\"");#NormalTok(", ");#StringTok("\".\"");#NormalTok(", ");#StringTok("\"*\"");#NormalTok(", ");#StringTok("\"( )\"");#NormalTok("),");],
[#NormalTok("  ");#StringTok("`");#AttributeTok("O que faz");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");],
[#NormalTok("    ");#StringTok("\"começo do texto\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"fim do texto\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"um dígito (0 a 9)\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"exatamente 4 vezes do anterior\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"qualquer caractere\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"zero ou mais do anterior\"");#NormalTok(",");],
[#NormalTok("    ");#StringTok("\"grupo de captura — vira uma coluna\"");],
[#NormalTok("  ),");],
[#NormalTok("  ");#AttributeTok("check.names =");#NormalTok(" ");#ConstantTok("FALSE");],
[#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(regex_guia)");],));
#figure([
#box(image("capitulos\\capitulo05/preparando_os_dados_files/figure-typst/tbl-regex-1.png"))

], caption: figure.caption(
position: top, 
[
As peças de regex mais usadas na arrumação de dados.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-regex>


Com essas peças, o padrão #NormalTok("^([0-9]{4}) - (.*)$"); lido sobre #NormalTok("2025 - Valor US$ FOB"); diz: "no começo, quatro dígitos (capture como grupo 1: #NormalTok("2025");), depois um espaço-traço-espaço, depois qualquer coisa até o fim (capture como grupo 2: #NormalTok("Valor US$ FOB");)". Os dois grupos viram as colunas #NormalTok("ano"); e #NormalTok("metrica");.

Há só uma regra de ouro para não errar: #strong[o número de grupos #NormalTok("( )"); tem de ser igual ao número de nomes que você dá]. Dois parênteses, dois nomes. E um sinal claro de que a regex não casou: a coluna extraída sai #strong[toda vazia] (#NormalTok("NA");) --- aí é conferir o padrão e tentar de novo. Na CatalyseR, o botão "?" ao lado do seletor traz esse mesmo guia, e a interface avisa quando os números não batem.

== Armadilhas comuns
<armadilhas-comuns>
Arrumar dados tem seus tropeços clássicos. Conhecê-los de antemão economiza cabelo branco.

O primeiro é a #strong[coerção que vira #NormalTok("NA");]. Ao converter texto em número, qualquer valor que não seja numérico --- um "s/d", uma vírgula fora do lugar --- vira #NormalTok("NA"); silenciosamente. Sempre confira quantos #NormalTok("NA"); surgiram depois de um #NormalTok("as.numeric()");.

O segundo aparece ao #strong[alargar com chaves duplicadas]. Se as colunas de identificação não distinguem cada linha de forma única, o #NormalTok("pivot_wider()"); não sabe qual valor colocar em cada célula e devolve listas em vez de números, com um aviso de que "os valores não estão unicamente identificados". A solução é garantir que os identificadores sejam, de fato, únicos.

O terceiro é a #strong[regex que não casa], que já mencionamos: coluna nova toda vazia. Em geral é um detalhe no padrão --- um espaço a mais, uma barra invertida faltando.

E o quarto, mais estético que grave: #strong[nomes não sintáticos]. Colunas como #NormalTok("Valor US$ FOB"); funcionam, mas exigem crases toda vez que você as chama. Vale renomear para #NormalTok("valor_usd");, #NormalTok("massa_kg"); --- nomes curtos, sem espaço nem símbolo. Seu "eu do futuro" agradece.

== Da arrumação à análise
<da-arrumação-à-análise>
Repare no que ganhamos. O #NormalTok("analise");, agora #emph[tidy], está pronto para o próximo capítulo: uma coluna #NormalTok("ano"); no eixo x, #NormalTok("Captura_t"); no eixo y, e o gráfico de série temporal sai num piscar. Se quiséssemos comparar a captura entre portos, um boxplot com #NormalTok("Porto"); no eixo x já estaria a um passo. Cada arrumação que fizemos foi, no fundo, o rascunho de uma análise adiante.

Essa é a lição que atravessa a Unidade II: #strong[preparar não é perder tempo antes do trabalho --- é onde o trabalho começa]. Um boxplot pede grupos bem definidos (que a tipagem garante); uma regressão pede duas colunas numéricas limpas (que a arrumação entrega); um teste de qui-quadrado pede uma tabela cruzada (que nasce de dados #emph[tidy]). Coletar bem, arrumar bem, e então analisar bem --- nessa ordem.

#quote(block: true)[
#strong[Resumo do capítulo.] (1) Dados #emph[tidy] têm uma linha por observação, uma coluna por variável, um valor por célula; (2) empilhe (#NormalTok("pivot_longer");) para tirar o ano/medida do cabeçalho, e alargue (#NormalTok("pivot_wider");) para deixar cada medida em sua coluna; (3) separe (#NormalTok("extract");) quando a informação está grudada dentro de uma célula; (4) finalize com filtro, tipagem e recodificação; (5) a regex é só um padrão de texto --- cada grupo #NormalTok("( )"); vira uma coluna. Na CatalyseR, cada passo no mouse gera o script #NormalTok(".R"); reproduzível.
]

== Para praticar
<para-praticar-3>
+ Com o #NormalTok("treino_desembarque");, empilhe as colunas de ano e #strong[pare no formato longo] (sem alargar). Compare o número de linhas antes e depois --- de onde vieram as linhas novas?
+ No #NormalTok("treino_coletas");, separe a coluna #NormalTok("estacao_periodo"); (valores como #NormalTok("E03_Seca");) em #NormalTok("estacao"); e #NormalTok("periodo");. Qual regex resolve com dois grupos?
+ Volte ao #NormalTok("tidy_final"); e #strong[renomeie] #NormalTok("Captura_t"); e #NormalTok("Receita_mil"); para nomes bem curtos. Depois filtre só o porto de Bragança e faça um gráfico simples da captura por ano.

= Análise Exploratória de Dados
<análise-exploratória-de-dados>
Ou: conhecer os dados já é preparar as análises que vêm depois

\
#block[
#callout(
body: 
[
Você recebe uma planilha com quase mil caranguejos medidos no mangue de Bragança e sente o impulso de já rodar um teste, traçar uma reta, cravar uma conclusão. Calma. Antes de qualquer cálculo, há uma pergunta que decide todo o resto: #strong[de que tipo é cada coluna desses dados?] Quem responde isso primeiro raramente erra o teste depois.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Estatística começa com curiosidade, não com fórmula. Antes de comparar médias ou ajustar modelos, a gente #strong[olha] os dados: quantas observações há, que variáveis foram medidas, como elas se distribuem, se há buracos (valores ausentes) ou números que destoam. Essa etapa tem nome --- #strong[análise exploratória de dados] --- e ela existe para uma coisa muito prática: descobrir o que os dados #emph[permitem] perguntar. É aqui que a #strong[estatística descritiva] entra, resumindo um monte de números em poucas medidas que cabem na cabeça.

Mais do que descrever, este capítulo ensina a #strong[reconhecer o tipo de cada variável]. Esse conhecimento é o que vai, lá na frente, dizer qual análise é possível, quais pressupostos ela exige e até como os dados deveriam ter sido coletados. Guarde essa ideia: #strong[o tipo da variável é a bússola que aponta o teste]. Foi ela, aliás, que orientou o capítulo anterior: ao planejar a coleta, é o tipo pretendido de cada variável que já decide, desde o campo, quais análises serão possíveis.

E é aqui que esta etapa faz jus ao nome da unidade: explorar não é enrolação antes do "trabalho de verdade" --- é onde você #strong[prepara], uma a uma, as análises que virão. Cada resumo e cada gráfico daqui já é o rascunho de um teste adiante: o boxplot que insinua um teste #emph[t], a nuvem de pontos que pede uma regressão, a tabela cruzada que chama um qui-quadrado. Na CatalyseR, esse preparo tem um lugar próprio --- você seleciona as variáveis, filtra o que interessa e declara o tipo de cada coluna antes de rodar qualquer análise. E há uma recompensa concreta da disciplina #emph[tidy] que vimos ao planejar a coleta: uma planilha de Excel bem-arrumada --- cada linha uma observação, cada coluna uma variável --- chega #strong[pronta] a esse painel, sem retrabalho; anotada de qualquer jeito, obriga a limpar tudo antes de começar.

== Os dados: caranguejos do mangue de Bragança
<os-dados-caranguejos-do-mangue-de-bragança>
Vamos trabalhar com o conjunto #NormalTok("biometria_caranguejos");, do pacote #NormalTok("EAPADados");. São medidas reais de caranguejos-uçá capturados em Bragança (Pará): para cada indivíduo, registrou-se o #strong[local] de captura, a #strong[estação] do ano, o #strong[sexo] e duas medidas da carapaça --- a #strong[largura] (LC) e o #strong[comprimento] (CC), em milímetros.

#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(caranguejos)");],));
#block[
#Skylighting(([#NormalTok("Rows: 993");],
[#NormalTok("Columns: 5");],
[#NormalTok("$ Local   <fct> Caratateua, Caratateua, Caratateua, Caratateua, Caratateua, Ca…");],
[#NormalTok("$ Sexo    <fct> Macho, Macho, Macho, Macho, Macho, Macho, Macho, Macho, Macho,…");],
[#NormalTok("$ Estacao <fct> Seca, Seca, Seca, Seca, Seca, Seca, Seca, Seca, Seca, Seca, Se…");],
[#NormalTok("$ LC      <dbl> 60, 63, 69, 65, 64, 70, 60, 59, 63, 64, 68, 65, 62, 61, 74, 56…");],
[#NormalTok("$ CC      <dbl> 56, 61, 67, 62, 62, 68, 58, 56, 60, 60, 67, 64, 60, 58, 72, 52…");],));
]
]
Repare na primeira coluna da saída: ao lado de cada variável, o R já anuncia o seu tipo (#NormalTok("<fct>"); para fator, #NormalTok("<dbl>"); para número real). Esse rótulo discreto é a informação mais importante da tela.

== O que cada coluna é, de verdade
<o-que-cada-coluna-é-de-verdade>
Nem todo número é "numérico" e nem todo texto é "categórico". O tipo de uma variável não é uma formalidade do R --- é a natureza do que foi medido. Dá para organizar tudo em duas grandes famílias.

As #strong[variáveis categóricas (qualitativas)] classificam o indivíduo em grupos. Quando os grupos não têm ordem natural, são #strong[nominais] --- é o caso de #NormalTok("Local"); (Ajuruteua ou Caratateua) e #NormalTok("Sexo"); (Macho ou Fêmea): ninguém é "mais" que o outro, são só rótulos. Quando existe uma ordem, são #strong[ordinais] --- pense em classes de tamanho "pequeno \< médio \< grande", onde a sequência importa mas a distância entre as classes não é fixa. No nosso conjunto, #NormalTok("Estacao"); (Seca, Chuvosa) é nominal, mas poderia virar ordinal se a tratássemos como um ciclo.

As #strong[variáveis numéricas (quantitativas)] medem quanto. Quando resultam de contagem e só assumem valores inteiros, são #strong[discretas] --- o número de ovos numa desova, a quantidade de caranguejos por armadilha. Quando podem assumir qualquer valor dentro de um intervalo, limitadas só pela precisão do instrumento, são #strong[contínuas] --- é o caso de #NormalTok("LC"); e #NormalTok("CC");, que poderiam ser 62 mm, 62,3 mm ou 62,37 mm.

Por que isso importa tanto? Porque #strong[a família da variável decide o que se pode calcular e qual teste faz sentido]. Média e desvio padrão só têm significado para variáveis numéricas; para categóricas, o que se conta é frequência. Comparar a largura média entre machos e fêmeas pede um teste #emph[t]\; verificar se sexo e estação estão associados pede um qui-quadrado. Errar o tipo da variável é errar a análise inteira --- por isso começamos por aqui.

#block[
#Skylighting(([#CommentTok("# o R distingue fatores de variáveis numéricas");],
[#FunctionTok("sapply");#NormalTok("(caranguejos, class)");],));
#block[
#Skylighting(([#NormalTok("    Local      Sexo   Estacao        LC        CC ");],
[#NormalTok(" \"factor\"  \"factor\"  \"factor\" \"numeric\" \"numeric\" ");],));
]
]
== Resumindo as variáveis numéricas
<resumindo-as-variáveis-numéricas>
Para #NormalTok("LC"); e #NormalTok("CC");, queremos as #strong[medidas de tendência central] (onde os dados se concentram) e as de #strong[dispersão] (o quanto se espalham). A média e a mediana respondem à primeira pergunta; o desvio padrão e o coeficiente de variação, à segunda.

#block[
#Skylighting(([#NormalTok("caranguejos ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n        =");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(LC)),");],
[#NormalTok("    ");#AttributeTok("media_LC =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(LC, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("mediana_LC =");#NormalTok(" ");#FunctionTok("median");#NormalTok("(LC, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("dp_LC    =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(LC, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok("),");],
[#NormalTok("    ");#AttributeTok("cv_LC    =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(LC, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(") ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(LC, ");#AttributeTok("na.rm =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(") ");#SpecialCharTok("*");#NormalTok(" ");#DecValTok("100");],
[#NormalTok("  )");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 1 × 5");],
[#NormalTok("      n media_LC mediana_LC dp_LC cv_LC");],
[#NormalTok("  <int>    <dbl>      <dbl> <dbl> <dbl>");],
[#NormalTok("1   993     65.5         66  6.67  10.2");],));
]
]
Um detalhe que parece bobo e não é: quando a #strong[média e a mediana ficam próximas], a distribuição é mais ou menos simétrica; quando se afastam, há assimetria --- sinal de que medidas baseadas na média (como o desvio padrão) podem enganar. Esse diagnóstico, feito a olho, já antecipa se um teste paramétrico vai se sentir confortável com esses dados.

== Contando as variáveis categóricas
<contando-as-variáveis-categóricas>
Para as qualitativas, o resumo é a #strong[tabela de frequência]: quantos indivíduos caem em cada categoria.

#block[
#Skylighting(([#FunctionTok("table");#NormalTok("(caranguejos");#SpecialCharTok("$");#NormalTok("Sexo)");],));
#block[
#Skylighting(([],
[#NormalTok("Fêmea Macho ");],
[#NormalTok("  303   690 ");],));
]
#Skylighting(([#FunctionTok("prop.table");#NormalTok("(");#FunctionTok("table");#NormalTok("(caranguejos");#SpecialCharTok("$");#NormalTok("Sexo)) ");#SpecialCharTok("|>");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#DecValTok("3");#NormalTok(")");],));
#block[
#Skylighting(([],
[#NormalTok("Fêmea Macho ");],
[#NormalTok("0.305 0.695 ");],));
]
]
== Gráficos que dão pistas sobre a análise
<gráficos-que-dão-pistas-sobre-a-análise>
Aqui está o segredo da análise exploratória: #strong[cada gráfico sugere um teste]. Não desenhamos por enfeite --- desenhamos para enxergar a pergunta certa antes de respondê-la.

Comece pela distribuição de uma variável numérica. O #strong[histograma] mostra a forma: se ela lembra um sino simétrico, métodos paramétricos (que assumem normalidade) tendem a funcionar; se é torta ou tem duas corcovas, acenda o alerta.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" LC)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_histogram");#NormalTok("(");#AttributeTok("bins =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Frequência\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo04/analise_exploratoria_statistica_descritiva_files/figure-typst/fig-hist-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribuição da largura da carapaça. Uma forma aproximadamente simétrica é o primeiro sinal verde para testes paramétricos.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-hist>


Agora cruze a numérica com uma categórica. O #strong[boxplot] da largura por sexo compara grupos de um golpe: se as caixas estão claramente deslocadas, há indício de diferença de médias --- e o próximo passo natural é um #strong[teste #emph[t]] (dois grupos) ou uma #strong[ANOVA] (três ou mais). Esse gráfico é, literalmente, o rascunho do capítulo seguinte.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Sexo, ");#AttributeTok("y =");#NormalTok(" LC, ");#AttributeTok("fill =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo04/analise_exploratoria_statistica_descritiva_files/figure-typst/fig-box-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Largura da carapaça por sexo. Caixas deslocadas sugerem diferença de médias --- pista para um teste t.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-box>


Por fim, cruze duas numéricas. O #strong[diagrama de dispersão] entre largura e comprimento revela se uma cresce junto com a outra: uma nuvem que sobe em linha é o convite para #strong[correlação e regressão] --- assunto da Unidade IV. Colorir por sexo ainda insinua se a relação muda entre grupos.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" LC, ");#AttributeTok("y =");#NormalTok(" CC, ");#AttributeTok("color =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento da carapaça (mm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo04/analise_exploratoria_statistica_descritiva_files/figure-typst/fig-disp-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Largura versus comprimento da carapaça, por sexo. Uma nuvem alongada e ascendente é pista para correlação e regressão.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-disp>


Em três gráficos, os dados já sussurraram três análises possíveis. Essa é a função da etapa exploratória: ela não conclui nada sozinha, mas aponta para onde olhar.

== Quando as duas variáveis são categóricas: a tabela de contingência
<quando-as-duas-variáveis-são-categóricas-a-tabela-de-contingência>
E se quisermos cruzar #strong[duas variáveis qualitativas] --- por exemplo, será que a proporção de machos e fêmeas muda entre a estação seca e a chuvosa? A ferramenta é a #strong[tabela de contingência], que conta quantos indivíduos caem em cada combinação de categorias.

#block[
#Skylighting(([#FunctionTok("table");#NormalTok("(caranguejos");#SpecialCharTok("$");#NormalTok("Sexo, caranguejos");#SpecialCharTok("$");#NormalTok("Estacao)");],));
#block[
#Skylighting(([#NormalTok("       ");],
[#NormalTok("        Chuvosa Seca");],
[#NormalTok("  Fêmea     216   87");],
[#NormalTok("  Macho     239  451");],));
]
]
A tabela crua resolve, mas não comunica. Para um relatório ou para o livro, vale apresentá-la no padrão visual do ecossistema EAPA --- o tema #strong[Ocean Gradient], com cabeçalho navy --- usando a mesma função #NormalTok("flextable_ocean()"); que a IDE CatalyseR emprega ao gerar os relatórios #NormalTok(".docx");.

#Skylighting(([#NormalTok("tab ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(caranguejos");#SpecialCharTok("$");#NormalTok("Sexo, caranguejos");#SpecialCharTok("$");#NormalTok("Estacao)");],
[],
[#CommentTok("# transformar a tabela em data frame com rótulos e total por linha");],
[#NormalTok("tab_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame.matrix");#NormalTok("(tab)");],
[#NormalTok("tab_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cbind");#NormalTok("(");#AttributeTok("Sexo =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(tab_df), tab_df, ");#AttributeTok("Total =");#NormalTok(" ");#FunctionTok("rowSums");#NormalTok("(tab_df))");],
[#FunctionTok("rownames");#NormalTok("(tab_df) ");#OtherTok("<-");#NormalTok(" ");#ConstantTok("NULL");],
[],
[#FunctionTok("flextable_ocean");#NormalTok("(tab_df)");],));
#figure([
#box(image("capitulos\\capitulo04/analise_exploratoria_statistica_descritiva_files/figure-typst/tbl-contingencia-1.png"))

], caption: figure.caption(
position: top, 
[
Distribuição de caranguejos por sexo e estação do ano (frequências absolutas), no mangue de Bragança (PA).
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-contingencia>


Repare: até aqui apenas #strong[descrevemos] a associação --- contamos e organizamos. A tabela sugere que a divisão entre sexos parece semelhante nas duas estações, mas "parecer" não é "ser". Para decidir se essa associação é real ou fruto do acaso amostral, precisamos de um #strong[teste de hipótese] --- o #strong[qui-quadrado de independência] ---, e ele exige a lógica da inferência. Por isso ele fica para a Unidade IV, onde reencontraremos exatamente esta tabela e finalmente a colocaremos à prova.

#block[
#callout(
body: 
[
Antes de testar, conheça os dados. Toda variável pertence a uma família --- #strong[categórica] (nominal ou ordinal) ou #strong[numérica] (discreta ou contínua) --- e é essa família que decide o que se pode calcular e qual teste faz sentido. A estatística descritiva resume as numéricas com medidas de centro e dispersão, e as categóricas com tabelas de frequência. Os gráficos não enfeitam: o histograma fala de normalidade, o boxplot insinua diferença de médias, o diagrama de dispersão aponta relações. E quando cruzamos duas categóricas, a tabela de contingência descreve a associação --- cujo teste formal virá na inferência.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Troque #NormalTok("LC"); por #NormalTok("CC"); nos resumos e gráficos. A forma da distribuição muda? E a conclusão sobre simetria?
+ Construa a tabela de contingência de #NormalTok("Local"); por #NormalTok("Estacao");. Qual combinação concentra mais capturas?
+ Classifique cada variável de #NormalTok("biometria_caranguejos"); como nominal, ordinal, discreta ou contínua --- e, para cada uma, anote que tipo de análise ela tornaria possível.

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Fechamos aqui a unidade #strong[Antes da análise]. Antes de virar a página para o primeiro teste, faça as pazes com estas sete perguntas --- se você responde "sim" a todas, dificilmente vai errar o teste por descuido com o básico:

+ Minha #strong[pergunta] de pesquisa está clara?
+ Sei qual é a #strong[variável resposta] --- aquilo que quero explicar ou comparar?
+ Sei o #strong[tipo] de cada variável envolvida, numérica ou categórica?
+ Sei se o meu estudo é #strong[observacional] ou #strong[experimental]?
+ A #strong[unidade amostral] (ou experimental) está bem definida --- e não confundi réplica com subamostra?
+ Já #strong[descrevi e visualizei] os dados antes de qualquer teste?
+ O #strong[desenho] da pesquisa combina com o teste que pretendo usar?

Cada "sim" daqui foi construído nesta unidade: os quatro primeiros no planejamento, os três últimos na exploração. Com eles no bolso, os próximos capítulos --- teste #emph[t], ANOVA, qui-quadrado, correlação, regressão --- deixam de ser um cardápio confuso e passam a ser a consequência natural de um bom plano.

]
, 
title: 
[
Checklist: pronto para escolher o teste?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#part[Unidade III · Comparar grupos — inferência]
= Testes Paramétricos para Uma e Duas Amostras
<testes-paramétricos-para-uma-e-duas-amostras>
Ou: a ração da propaganda faz mesmo a Artemia crescer mais?

\
#block[
#callout(
body: 
[
Uma fábrica de ração anuncia, em letras garrafais, que a sua ração de farelo de arroz faz a #emph[Artemia] crescer mais rápido que a concorrente, de farelo de babaçu. Soa convincente --- mas é propaganda. Será que a diferença existe de verdade, ou é só conversa de marketing em cima do acaso de algumas medições? Há um jeito honesto de decidir: montar o experimento e aplicar um #strong[teste #emph[t]].

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Quando queremos comparar a #strong[média] de uma variável numérica entre #strong[dois grupos], a ferramenta clássica é o #strong[teste #emph[t]]. Ele responde a uma pergunta direta: a diferença que vejo entre as médias amostrais é grande o bastante para não ser obra do acaso? Como assume que os dados são aproximadamente #strong[normais], ele faz parte da família dos testes #strong[paramétricos] --- os de maior poder, quando seus pressupostos se sustentam (quando não, recorremos aos não-paramétricos da Unidade IV).

== O experimento: duas rações para a #emph[Artemia]
<o-experimento-duas-rações-para-a-artemia>
Para testar a alegação da fábrica, montamos um experimento #strong[em laboratório], onde quase tudo pode ser controlado. A #emph[Artemia salina] (um microcrustáceo usado como alimento vivo na aquicultura) é cultivada em pequenos aquários idênticos. Cada aquário recebe #strong[uma] das duas rações --- A (farelo de arroz) ou B (farelo de babaçu) --- e, ao final, medimos a #strong[taxa de crescimento] (em mg/dia).

O desenho é um #strong[Delineamento Inteiramente Casualizado (DIC)] com dois tratamentos e #strong[7 réplicas por tratamento]: 14 pequenos aquários, sorteados ao acaso entre as duas rações (#ref(<fig-experimento-artemia>, supplement: [Figura])). Cada aquário é uma #strong[unidade experimental independente] --- sete medidas por ração, sem pseudo-replicação.

#figure([
#box(image("capitulos\\capitulo07/../../images/artemia-experimentos.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Desenho do experimento de comparação de duas rações para a #emph[Artemia] em delineamento inteiramente casualizado (DIC): 7 pequenos aquários por tratamento (A --- farelo de arroz; B --- farelo de babaçu), alimentados por uma mesma bomba de ar e mantidos sob condições idênticas (250 mL, salinidade 35 g/L, aeração contínua, 25 ± 1 °C e densidade inicial igual de #emph[Artemia]). Cada aquário é uma réplica independente.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-experimento-artemia>


#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(artemia)");],));
#block[
#Skylighting(([#NormalTok("Rows: 14");],
[#NormalTok("Columns: 2");],
[#NormalTok("$ racao                   <fct> A, A, A, A, A, A, A, B, B, B, B, B, B, B");],
[#NormalTok("$ taxa_crescimento_mg_dia <dbl> 4.2, 3.6, 4.6, 4.3, 4.1, 3.5, 4.3, 3.7, 4.0, 3…");],));
]
]
Antes de qualquer teste, #strong[veja] os dados. Um boxplot já mostra se as nuvens estão deslocadas.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(artemia, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" racao, ");#AttributeTok("y =");#NormalTok(" taxa_crescimento_mg_dia, ");#AttributeTok("fill =");#NormalTok(" racao)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.08");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Ração\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Taxa de crescimento (mg/dia)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo07/testes_parametricos_uma_duas_amostras_files/figure-typst/fig-box-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Taxa de crescimento da Artemia por ração. A ração A parece puxar as medidas para cima.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-box>


== Conferindo os pressupostos
<conferindo-os-pressupostos>
O teste #emph[t] pede duas coisas: #strong[normalidade] dentro de cada grupo e, na sua versão clássica, #strong[variâncias parecidas] entre os grupos. Com amostras pequenas, checamos a normalidade com o teste de Shapiro-Wilk e a igualdade de variâncias com o teste #emph[F].

#block[
#Skylighting(([#CommentTok("# normalidade dentro de cada ração");],
[#FunctionTok("tapply");#NormalTok("(artemia");#SpecialCharTok("$");#NormalTok("taxa_crescimento_mg_dia, artemia");#SpecialCharTok("$");#NormalTok("racao, ");#ControlFlowTok("function");#NormalTok("(x) ");#FunctionTok("shapiro.test");#NormalTok("(x)");#SpecialCharTok("$");#NormalTok("p.value)");],));
#block[
#Skylighting(([#NormalTok("        A         B ");],
[#NormalTok("0.3526517 0.6621903 ");],));
]
#Skylighting(([#CommentTok("# igualdade de variâncias entre as rações");],
[#FunctionTok("var.test");#NormalTok("(taxa_crescimento_mg_dia ");#SpecialCharTok("~");#NormalTok(" racao, ");#AttributeTok("data =");#NormalTok(" artemia)");#SpecialCharTok("$");#NormalTok("p.value");],));
#block[
#Skylighting(([#NormalTok("[1] 0.9558986");],));
]
]
Os dois #emph[p]-valores ficam acima de 0,05: não há evidência contra a normalidade nem contra a igualdade de variâncias. Caminho livre para o teste #emph[t] clássico (de variâncias iguais). Quando a igualdade de variâncias é duvidosa, a escolha segura é o #strong[teste #emph[t] de Welch], que o R usa por padrão.

== O teste #emph[t]
<o-teste-t>
Rodamos o teste e apresentamos o resultado com #NormalTok("exibir_teste_t()");, do #NormalTok("EAPADados");: ela arruma a saída do #NormalTok("t.test()"); num formato enxuto e em português (médias, diferença, intervalo num campo só, #emph[t], gl, #emph[p], método e hipótese alternativa, já traduzidos) e ainda deixa a tabela apresentável --- com cara de console, mas organizada: fonte monoespaçada, centralizada, fundo verde acinzentado e sem linhas de grade. Por baixo, é o atalho de #NormalTok("arrumar_teste_t() |> flextable_cinza()"); numa chamada só.

#Skylighting(([#NormalTok("teste ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("t.test");#NormalTok("(taxa_crescimento_mg_dia ");#SpecialCharTok("~");#NormalTok(" racao, ");#AttributeTok("data =");#NormalTok(" artemia, ");#AttributeTok("var.equal =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(")");],
[#FunctionTok("exibir_teste_t");#NormalTok("(teste)");],));
#box(image("capitulos\\capitulo07/testes_parametricos_uma_duas_amostras_files/figure-typst/teste-t-1.png"))

#v(0.8em)
E aqui está a ponte #strong[do mouse ao código]: a leitura em uma frase sai pronta com a função canônica #NormalTok("relatar_teste_t_ind()"); --- a mesma que a IDE CatalyseR usa para montar o relatório #NormalTok(".docx");, onde a tabela é renderizada no tema Ocean por #NormalTok("flextable_ocean()");.

#quote(block: true)[
Foi conduzido um teste #emph[t] de Student para duas amostras independentes para variâncias iguais para comparar a variável a taxa de crescimento (mg/dia) entre os grupos definidos por o tipo de ração (A vs B). A média no grupo A foi de 4,09 e a média no grupo B foi de 3,47 (IC 95% da diferença \[0,15; 1,08\]). Os resultados indicaram uma diferença estatisticamente significativa entre as médias dos grupos, #emph[t]\(12,0) = 2,856, p = 0,014, sendo a média amostral do grupo A superior à média do grupo B. O tamanho do efeito, estimado pelo #emph[d] de Cohen, foi de 1,53, correspondendo a um efeito grande.
]

== Da significância à decisão
<da-significância-à-decisão>
O #emph[p]-valor de cerca de #strong[0,014] fica abaixo de 0,05: rejeitamos a hipótese de médias iguais. A ração A (farelo de arroz) produziu uma taxa de crescimento média de #strong[4,09 mg/dia] contra #strong[3,47 mg/dia] da ração B --- uma diferença que dificilmente é fruto do acaso. E não é só "significativa": o #strong[#emph[d] de Cohen] de cerca de #strong[1,5] indica um efeito #strong[grande], de real relevância prática.

Vale uma observação fina. A propaganda faz uma afirmação #strong[direcional] --- A é #emph[melhor] que B ---, o que justificaria um teste #strong[unilateral] (#NormalTok("alternative = \"greater\"");), cujo #emph[p]-valor (≈ 0,007) é a metade do bilateral. A regra de ouro é decidir o lado #strong[antes] de ver os dados; como a alegação já vinha da fábrica, o teste unilateral é defensável aqui. De todo modo, bilateral ou unilateral, a conclusão é a mesma: há evidência de que o farelo de arroz acelera o crescimento da #emph[Artemia].

#block[
#callout(
body: 
[
O teste #emph[t] compara as #strong[médias] de dois grupos e pergunta se a diferença escapa ao acaso. É #strong[paramétrico]: pede #strong[normalidade] (Shapiro-Wilk) e, na versão clássica, #strong[variâncias iguais] (teste #emph[F]); na dúvida, use o #emph[t] de #strong[Welch]. No experimento da #emph[Artemia] --- um DIC com 7 aquários por ração ---, a ração de farelo de arroz superou a de babaçu (#emph[t] ≈ 2,9, #emph[p] ≈ 0,014), com #strong[efeito grande] (#emph[d] de Cohen ≈ 1,5). Sempre acompanhe o #emph[p]-valor do #strong[tamanho do efeito]: significância diz que #emph[existe] diferença; o #emph[d] diz se ela #strong[importa].

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Refaça o teste com #NormalTok("var.equal = FALSE"); (Welch). O #emph[t], os graus de liberdade e o #emph[p]-valor mudam muito?
+ Rode a versão unilateral com #NormalTok("alternative = \"greater\""); (lembrando que o R compara o primeiro nível do fator). O que muda na conclusão?
+ Construa o intervalo de confiança de 99% para a diferença de médias (#NormalTok("conf.level = 0.99");). Ele ainda exclui o zero?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Testes Não-paramétricos
<testes-não-paramétricos>
Ou: o que fazer quando os dados não querem ser normais

\
#block[
#callout(
body: 
[
Você roda o teste de normalidade, ele dá significativo, e lá se vai o teste #emph[t] que você planejava. E agora? Jogar fora os dados? Fingir que não viu? Nem um nem outro. Existe toda uma família de testes que não pede normalidade --- eles trabalham com a #strong[ordem] dos valores, não com seus tamanhos exatos. São os #strong[testes não-paramétricos], e este capítulo mostra quando e como usá-los.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Os testes que vimos até aqui --- o #emph[t], e em breve a ANOVA --- são #strong[paramétricos]: assumem que os dados seguem (aproximadamente) uma distribuição conhecida, em geral a normal, e que as variâncias se comportam bem. Quando esses pressupostos valem, eles são poderosos. Mas a natureza nem sempre coopera: contagens de captura, dados muito assimétricos, amostras pequenas ou variáveis ordinais costumam quebrar a normalidade.

Aí entram os #strong[testes não-paramétricos]. Em vez de comparar médias, eles comparam #strong[postos] (a posição de cada valor quando ordenamos tudo). Trocar valores por ordens custa um pouco de poder estatístico, mas compra robustez: o teste deixa de se importar com a forma da distribuição. A regra prática é direta --- #emph[se os pressupostos do teste paramétrico se sustentam, use-o; se não, recorra ao seu primo não-paramétrico.]

#table(
  columns: (34%, 33%, 33%),
  align: (left,left,left,),
  table.header([Pergunta], [Teste paramétrico], [Equivalente não-paramétrico],),
  table.hline(),
  [Uma amostra / pareada], [teste #emph[t]], [Wilcoxon],
  [Dois grupos independentes], [teste #emph[t] independente], [Mann-Whitney (Wilcoxon)],
  [Três ou mais grupos], [ANOVA], [#strong[Kruskal-Wallis]],
  [Associação entre categóricas], [---], [#strong[Qui-quadrado]],
)
== Dois grupos: Mann-Whitney
<dois-grupos-mann-whitney>
Quando comparamos #strong[dois grupos independentes] e a normalidade não se sustenta, o substituto do teste #emph[t] é o #strong[teste de Mann-Whitney] (também chamado Wilcoxon para amostras independentes). No R, é a função #NormalTok("wilcox.test()");. A hipótese nula é que as duas distribuições estão deslocadas igualmente --- na prática, que não há diferença sistemática entre os grupos.

#block[
#Skylighting(([#FunctionTok("data");#NormalTok("(biometria_caranguejos)");],
[],
[#FunctionTok("wilcox.test");#NormalTok("(LC ");#SpecialCharTok("~");#NormalTok(" Sexo, ");#AttributeTok("data =");#NormalTok(" biometria_caranguejos)");],));
#block[
#Skylighting(([],
[#NormalTok("    Wilcoxon rank sum test with continuity correction");],
[],
[#NormalTok("data:  LC by Sexo");],
[#NormalTok("W = 97114, p-value = 0.07407");],
[#NormalTok("alternative hypothesis: true location shift is not equal to 0");],));
]
]
A leitura é a mesma de sempre: um #emph[p]-valor pequeno (abaixo de 0,05) indica que a diferença entre machos e fêmeas dificilmente é obra do acaso.

== Três ou mais grupos: Kruskal-Wallis
<três-ou-mais-grupos-kruskal-wallis>
Quando há #strong[três ou mais grupos] e a ANOVA não pode ser usada --- porque os resíduos não são normais ou as variâncias são muito desiguais ---, o teste certo é o de #strong[Kruskal-Wallis]. Ele é, exatamente, a versão não-paramétrica da ANOVA de um fator: pergunta se #emph[ao menos um grupo] tende a apresentar valores sistematicamente maiores que os demais, comparando postos em vez de médias.

Vamos usar o conjunto #NormalTok("captura_petrechos");, que traz a captura por unidade de esforço (CPUE) de peixes obtida por três aparelhos de pesca diferentes. Como CPUE é uma contagem e costuma ser bem assimétrica, é um caso natural para o Kruskal-Wallis.

#Skylighting(([#FunctionTok("data");#NormalTok("(captura_petrechos)");],
[],
[#FunctionTok("ggplot");#NormalTok("(captura_petrechos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Petrecho, ");#AttributeTok("y =");#NormalTok(" CPUE, ");#AttributeTok("fill =");#NormalTok(" Petrecho)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"CPUE (indivíduos)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo08/nao-parametricos_uma_duas_amostras_files/figure-typst/fig-kruskal-1.svg"))
], caption: figure.caption(
position: bottom, 
[
CPUE por aparelho de pesca. Distribuições assimétricas e de dispersão desigual pedem um teste não-paramétrico.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-kruskal>


#block[
#Skylighting(([#FunctionTok("kruskal.test");#NormalTok("(CPUE ");#SpecialCharTok("~");#NormalTok(" Petrecho, ");#AttributeTok("data =");#NormalTok(" captura_petrechos)");],));
#block[
#Skylighting(([],
[#NormalTok("    Kruskal-Wallis rank sum test");],
[],
[#NormalTok("data:  CPUE by Petrecho");],
[#NormalTok("Kruskal-Wallis chi-squared = 2.9985, df = 2, p-value = 0.2233");],));
]
]
Se o #emph[p]-valor for pequeno, concluímos que #strong[pelo menos um aparelho] difere dos outros na captura --- e o passo seguinte seria uma comparação múltipla de postos (por exemplo, o teste de Dunn) para descobrir #emph[quais] pares diferem, assim como o Tukey faz depois da ANOVA.

== Associação entre categóricas: o qui-quadrado
<associação-entre-categóricas-o-qui-quadrado>
Até aqui comparamos uma variável #strong[numérica] entre grupos. Mas e quando as #strong[duas] variáveis são #strong[categóricas]? Voltemos à tabela de contingência que construímos na Unidade II, cruzando o #strong[sexo] e a #strong[estação] dos caranguejos de Bragança. Lá, apenas a descrevemos. Agora temos a ferramenta para testá-la.

O #strong[teste do qui-quadrado de independência] pergunta: #emph[as duas variáveis são independentes, ou existe associação entre elas?] A lógica é comparar as frequências que #strong[observamos] com as que #strong[esperaríamos] se não houvesse associação nenhuma. Se a distância entre observado e esperado for grande demais para o acaso explicar, rejeitamos a independência.

#Skylighting(([#NormalTok("tab ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(biometria_caranguejos");#SpecialCharTok("$");#NormalTok("Sexo, biometria_caranguejos");#SpecialCharTok("$");#NormalTok("Estacao)");],
[],
[#NormalTok("tab_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame.matrix");#NormalTok("(tab)");],
[#NormalTok("tab_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cbind");#NormalTok("(");#AttributeTok("Sexo =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(tab_df), tab_df, ");#AttributeTok("Total =");#NormalTok(" ");#FunctionTok("rowSums");#NormalTok("(tab_df))");],
[#FunctionTok("rownames");#NormalTok("(tab_df) ");#OtherTok("<-");#NormalTok(" ");#ConstantTok("NULL");],
[#FunctionTok("flextable_ocean");#NormalTok("(tab_df)");],));
#figure([
#box(image("capitulos\\capitulo08/nao-parametricos_uma_duas_amostras_files/figure-typst/tbl-contingencia-teste-1.png"))

], caption: figure.caption(
position: top, 
[
Frequências observadas de caranguejos por sexo e estação --- a mesma tabela da Unidade II, agora levada ao teste.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-contingencia-teste>


#block[
#Skylighting(([#FunctionTok("chisq.test");#NormalTok("(tab)");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's Chi-squared test with Yates' continuity correction");],
[],
[#NormalTok("data:  tab");],
[#NormalTok("X-squared = 112.44, df = 1, p-value < 2.2e-16");],));
]
]
A interpretação fecha o ciclo: um #emph[p]-valor #strong[acima] de 0,05 indica que sexo e estação são #strong[independentes] --- a proporção de machos e fêmeas não muda de uma estação para a outra. Um #emph[p]-valor #strong[abaixo] de 0,05 indicaria o contrário: há #strong[associação], e a composição por sexo depende da estação. Foi exatamente para responder a essa pergunta que, lá atrás, valeu a pena descrever a tabela com cuidado.

#block[
#callout(
body: 
[
O teste assume que as #strong[frequências esperadas] não são pequenas demais (a regra usual pede ao menos 5 em cada célula). Com células muito pequenas, prefira o #strong[teste exato de Fisher] (#NormalTok("fisher.test()");). Vale sempre inspecionar #NormalTok("chisq.test(tab)$expected"); antes de confiar no resultado.

]
, 
title: 
[
Um cuidado com o qui-quadrado
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Quando a normalidade falha, os testes não-paramétricos salvam a análise trocando valores por #strong[postos]. Para dois grupos independentes, #strong[Mann-Whitney] substitui o teste #emph[t]\; para três ou mais, #strong[Kruskal-Wallis] substitui a ANOVA. E quando as duas variáveis são categóricas, o #strong[qui-quadrado de independência] decide se há associação --- comparando o que observamos com o que esperaríamos sob independência. Pagamos um pouco de poder em troca de robustez; é um bom negócio quando os pressupostos paramétricos não se sustentam.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Compare #NormalTok("CC"); entre sexos com #NormalTok("wilcox.test()");. O resultado concorda com o de #NormalTok("LC");?
+ Rode o Kruskal-Wallis da CPUE e, em seguida, inspecione visualmente quais aparelhos parecem diferir. Como você testaria isso formalmente?
+ Construa a tabela de contingência de #NormalTok("Local"); por #NormalTok("Estacao"); e aplique o qui-quadrado. Há associação entre onde e quando os caranguejos foram capturados?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Análise de Variância (ANOVA) em Estudos Observacionais e Experimentais
<análise-de-variância-anova-em-estudos-observacionais-e-experimentais>
Ou: como descobrir se uma ração realmente faz o peixe crescer mais --- e provar isso

\
#block[
#callout(
body: 
[
Você testou quatro rações no seu cultivo, anotou o peso final dos peixes em cada tanque e agora bate aquela dúvida: a ração C #strong[realmente] fez os peixes crescerem mais, ou foi só sorte da amostra? Olhar para as médias não basta --- é preciso um teste que separe o #strong[efeito do tratamento] do #strong[acaso].

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Quando queremos comparar as médias de #strong[três ou mais grupos] independentes, o teste #emph[t] já não serve (ele compara só dois de cada vez, e repeti-lo inflaciona o erro). A ferramenta certa é a #strong[Análise de Variância (ANOVA)]. O nome engana um pouco: apesar de falar em #emph[variância], o objetivo é comparar #strong[médias]. A ideia genial de R. A. Fisher foi: se a variação #strong[entre] os grupos for muito maior do que a variação #strong[dentro] dos grupos, então pelo menos um tratamento se destaca do acaso.

Nas ciências da pesca e aquicultura, a ANOVA está em toda parte: comparar dietas, densidades de estocagem, salinidades, locais de coleta, formulações de ração --- sempre que há #strong[um fator] com vários níveis e #strong[uma resposta numérica].

== O experimento: quatro rações iso-proteicas para bagres
<o-experimento-quatro-rações-iso-proteicas-para-bagres>
Vamos usar um conjunto de dados clássico, disponível no pacote #NormalTok("EAPADados"); como #NormalTok("isoproteica_bagre");, reproduzido de #cite(<bhujel2011>, form: "prose") (Tabela 7.4). Quatro #strong[rações comerciais iso-proteicas] (mesmo teor de proteína, mas níveis diferentes de lipídio) foram comparadas. Em um único tanque grande, instalaram-se gaiolas com 50 peixes cada; cada ração teve 5 gaiolas (réplicas). Durante o manejo, os peixes de #strong[uma] gaiola da ração #strong[C] escaparam --- por isso esse nível tem só 4 réplicas, e o experimento fica #strong[desbalanceado] (19 observações no total). Cada valor é o #strong[peso médio final (g)] dos peixes de uma gaiola. A #ref(<fig-experimento>, supplement: [Figura]) resume todo o desenho do experimento.

#figure([
#box(image("capitulos\\capitulo09/../../images/experimento_anova_bagres.png", width: 85.0%))
], caption: figure.caption(
position: bottom, 
[
Esquema do experimento de comparação de quatro rações iso-proteicas para bagres em delineamento inteiramente casualizado (DIC): um único tanque com gaiolas-rede dispostas em quatro tratamentos (A--D) e cinco réplicas, alimentação com as quatro rações, pesagem final (g) e comparação das médias por ANOVA. Elaborado a partir de #cite(<bhujel2011>, form: "prose") (Tabela 7.4).
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-experimento>


#block[
#Skylighting(([#FunctionTok("str");#NormalTok("(dados)");],));
#block[
#Skylighting(([#NormalTok("tibble [19 × 2] (S3: tbl_df/tbl/data.frame)");],
[#NormalTok(" $ racao : Factor w/ 4 levels \"A\",\"B\",\"C\",\"D\": 1 1 1 1 1 2 2 2 2 2 ...");],
[#NormalTok(" $ peso_g: num [1:19] 86 83 91 84 87 88 87 94 86 89 ...");],));
]
]
#quote(block: true)[
#strong[Atenção à unidade experimental.] A unidade experimental é a #strong[gaiola], não o peixe. Cada réplica resume 50 peixes em um único número. Tratar cada peixe como observação independente seria #emph[pseudo-replicação] --- um erro comum e grave.
]

Este é um #strong[Delineamento Inteiramente Casualizado (DIC)]: um único fator (a ração, com 4 níveis), tratamentos atribuídos ao acaso e demais condições mantidas constantes. O modelo é:

$ Y_(i j) = m + T_i + R_(i j) $

em que $m$ é a média geral, $T_i$ o efeito da ração $i$ e $R_(i j)$ o erro aleatório. As hipóteses são:

$ H_0 : mu_A = mu_B = mu_C = mu_D #h(2em) upright("vs.") #h(2em) H_1 : upright("ao menos uma média difere.") $

=== Um olhar exploratório antes da conta
<um-olhar-exploratório-antes-da-conta>
Sempre #strong[veja] os dados antes de testar. Médias e dispersão por ração:

#Skylighting(([#NormalTok("resumo ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aggregate");#NormalTok("(peso_g ");#SpecialCharTok("~");#NormalTok(" racao, ");#AttributeTok("data =");#NormalTok(" dados,");],
[#NormalTok("                    ");#AttributeTok("FUN =");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("(x) ");#FunctionTok("c");#NormalTok("(");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("length");#NormalTok("(x),");],
[#NormalTok("                                        ");#AttributeTok("total =");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(x),");],
[#NormalTok("                                        ");#AttributeTok("media =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#FunctionTok("mean");#NormalTok("(x), ");#DecValTok("2");#NormalTok(")))");],
[#NormalTok("resumo ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("do.call");#NormalTok("(data.frame, resumo)");],
[#FunctionTok("names");#NormalTok("(resumo) ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"Ração\"");#NormalTok(", ");#StringTok("\"n\"");#NormalTok(", ");#StringTok("\"Total (g)\"");#NormalTok(", ");#StringTok("\"Média (g)\"");#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(resumo)");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-medias-1.png"))

], caption: figure.caption(
position: top, 
[
Totais, número de réplicas e médias por ração (conferem com a Tabela 7.4 do livro).
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-medias>


#Skylighting(([#FunctionTok("ggplot");#NormalTok("(dados, ");#FunctionTok("aes");#NormalTok("(racao, peso_g, ");#AttributeTok("fill =");#NormalTok(" racao)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(", ");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"grey30\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.1");#NormalTok(", ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"grey20\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ocean[");#DecValTok("1");#SpecialCharTok(":");#DecValTok("4");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Ração\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Peso médio final (g)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/fig-boxplot-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribuição do peso final por ração. A ração C se destaca visualmente.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-boxplot>


O boxplot já sugere que a ração #strong[C] puxa o crescimento para cima. Mas "sugerir" não é "provar" --- vamos à ANOVA.

== Por dentro da conta: a ANOVA na mão
<por-dentro-da-conta-a-anova-na-mão>
Antes de apertar o botão do R, vale entender #strong[o que] ele calcula. A ANOVA particiona a variação total em duas partes: a que vem do #strong[fator] (entre rações) e a que sobra como #strong[erro] (dentro das rações). Reproduzimos aqui exatamente os passos de #cite(<bhujel2011>, form: "prose").

#block[
#Skylighting(([#NormalTok("N  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nrow");#NormalTok("(dados)                       ");#CommentTok("# total de observações = 19");],
[#NormalTok("k  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nlevels");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("racao)              ");#CommentTok("# número de rações = 4");],
[#NormalTok("G  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("peso_g)                 ");#CommentTok("# grande total = 1748");],
[],
[#CommentTok("# Fator de correção");],
[#NormalTok("CF ");#OtherTok("<-");#NormalTok(" G");#SpecialCharTok("^");#DecValTok("2");#NormalTok(" ");#SpecialCharTok("/");#NormalTok(" N");],
[],
[#CommentTok("# Soma de quadrados total");],
[#NormalTok("SQ_total ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("peso_g");#SpecialCharTok("^");#DecValTok("2");#NormalTok(") ");#SpecialCharTok("-");#NormalTok(" CF");],
[],
[#CommentTok("# Soma de quadrados do tratamento (entre rações)");],
[#NormalTok("totais ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("tapply");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("peso_g, dados");#SpecialCharTok("$");#NormalTok("racao, sum)");],
[#NormalTok("ns     ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("tapply");#NormalTok("(dados");#SpecialCharTok("$");#NormalTok("peso_g, dados");#SpecialCharTok("$");#NormalTok("racao, length)");],
[#NormalTok("SQ_trat ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(totais");#SpecialCharTok("^");#DecValTok("2");#NormalTok(" ");#SpecialCharTok("/");#NormalTok(" ns) ");#SpecialCharTok("-");#NormalTok(" CF");],
[],
[#CommentTok("# Soma de quadrados do erro (por diferença)");],
[#NormalTok("SQ_erro ");#OtherTok("<-");#NormalTok(" SQ_total ");#SpecialCharTok("-");#NormalTok(" SQ_trat");],
[],
[#CommentTok("# Graus de liberdade e quadrados médios");],
[#NormalTok("gl_trat ");#OtherTok("<-");#NormalTok(" k ");#SpecialCharTok("-");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("gl_erro ");#OtherTok("<-");#NormalTok(" N ");#SpecialCharTok("-");#NormalTok(" k");],
[#NormalTok("QM_trat ");#OtherTok("<-");#NormalTok(" SQ_trat ");#SpecialCharTok("/");#NormalTok(" gl_trat");],
[#NormalTok("QM_erro ");#OtherTok("<-");#NormalTok(" SQ_erro ");#SpecialCharTok("/");#NormalTok(" gl_erro");],
[#NormalTok("F_obs   ");#OtherTok("<-");#NormalTok(" QM_trat ");#SpecialCharTok("/");#NormalTok(" QM_erro");],
[],
[#FunctionTok("round");#NormalTok("(");#FunctionTok("c");#NormalTok("(");#AttributeTok("CF =");#NormalTok(" CF, ");#AttributeTok("SQ_total =");#NormalTok(" SQ_total, ");#AttributeTok("SQ_trat =");#NormalTok(" SQ_trat,");],
[#NormalTok("        ");#AttributeTok("SQ_erro =");#NormalTok(" SQ_erro, ");#AttributeTok("QM_trat =");#NormalTok(" QM_trat, ");#AttributeTok("QM_erro =");#NormalTok(" QM_erro,");],
[#NormalTok("        ");#AttributeTok("F =");#NormalTok(" F_obs), ");#DecValTok("2");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("       CF  SQ_total   SQ_trat   SQ_erro   QM_trat   QM_erro         F ");],
[#NormalTok("160816.00    798.00    662.20    135.80    220.73      9.05     24.38 ");],));
]
]
#quote(block: true)[
#strong[Uma lição sobre a "fonte da verdade".] Fazendo as contas à mão e #strong[arredondando] no caminho, o livro publica $S Q_(t r a t) = 665$, $S Q_(e r r o) = 128$ e $F = 26$. O R, sem arredondar, devolve $S Q_(t r a t) = 662 \, 20$, $S Q_(e r r o) = 135 \, 80$ e $F = 24 \, 38$ (o próprio livro traz a soma de quadrados total como 161.609, quando o valor exato é 161.614). As diferenças são pequenas e #strong[não mudam a conclusão], mas ilustram um princípio do nosso ecossistema: quem manda no número final é o #strong[código], não a conta de papel. É por isso que a CatalyseR e este livro derivam tudo da #strong[mesma] função.
]

O valor crítico tabelado é $F_(3 \; thin 15 \; thin 0 \, 01) = 5 \, 42$. Como $F_(o b s) = 24 \, 4 gt.double 5 \, 42$, já antecipamos a rejeição de $H_0$. Vejamos isso pelo caminho prático.

== A ANOVA com o R (e com a CatalyseR)
<a-anova-com-o-r-e-com-a-catalyser>
Na prática, ninguém calcula somas de quadrados na mão. A função #NormalTok("aov()"); faz tudo:

#block[
#Skylighting(([#NormalTok("modelo ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("aov");#NormalTok("(peso_g ");#SpecialCharTok("~");#NormalTok(" racao, ");#AttributeTok("data =");#NormalTok(" dados)");],
[#FunctionTok("summary");#NormalTok("(modelo)");],));
#block[
#Skylighting(([#NormalTok("            Df Sum Sq Mean Sq F value  Pr(>F)    ");],
[#NormalTok("racao        3  662.2  220.73   24.38 5.1e-06 ***");],
[#NormalTok("Residuals   15  135.8    9.05                    ");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],));
]
]
No ecossistema EAPA, porém, não paramos no #NormalTok("summary()");. A função canônica #strong[#NormalTok("calcular_anova()");] do #NormalTok("EAPADados"); executa o ajuste, #strong[valida os pressupostos] e roda o #strong[pós-teste de Tukey] de uma vez, devolvendo um objeto que alimenta as tabelas, os gráficos e o relato --- #strong[a mesma função que a IDE CatalyseR usa] para gerar o relatório #NormalTok(".docx");. Esse é o "entrosamento": uma definição única, vários consumidores.

#block[
#Skylighting(([#NormalTok("r ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("calcular_anova");#NormalTok("(dados, ");#AttributeTok("dep_var =");#NormalTok(" ");#StringTok("\"peso_g\"");#NormalTok(", ");#AttributeTok("ind_var =");#NormalTok(" ");#StringTok("\"racao\"");#NormalTok(")");],));
]
A tabela de ANOVA formatada na identidade #strong[Ocean Gradient]:

#Skylighting(([#FunctionTok("flextable_ocean");#NormalTok("(");#FunctionTok("mostrar_anova");#NormalTok("(r))");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-anova-1.png"))

], caption: figure.caption(
position: top, 
[
Tabela de Análise de Variância (ANOVA) para o peso final por ração.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-anova>


== Os pressupostos: a ANOVA tem letras miúdas
<os-pressupostos-a-anova-tem-letras-miúdas>
Uma ANOVA só é confiável se os #strong[resíduos] forem aproximadamente normais e as #strong[variâncias] dos grupos forem parecidas (homocedasticidade). Verificamos isso com Shapiro-Wilk e Bartlett --- e, principalmente, com os olhos.

#Skylighting(([#FunctionTok("flextable_ocean");#NormalTok("(");#FunctionTok("mostrar_pressupostos");#NormalTok("(r))");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-pressupostos-1.png"))

], caption: figure.caption(
position: top, 
[
Validação dos pressupostos: normalidade dos resíduos e homogeneidade de variâncias.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-pressupostos>


#Skylighting(([#NormalTok("diag ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("residuos =");#NormalTok(" r");#SpecialCharTok("$");#NormalTok("residuals, ");#AttributeTok("ajustados =");#NormalTok(" r");#SpecialCharTok("$");#NormalTok("fitted)");],
[#FunctionTok("ggplot");#NormalTok("(diag, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" residuos)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_qq");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ocean[");#DecValTok("2");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_qq_line");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ocean[");#DecValTok("5");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Quantis teóricos\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Resíduos\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/fig-qq-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Normalidade dos resíduos: quanto mais perto da linha, melhor.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-qq>


#Skylighting(([#FunctionTok("ggplot");#NormalTok("(diag, ");#FunctionTok("aes");#NormalTok("(ajustados, residuos)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_hline");#NormalTok("(");#AttributeTok("yintercept =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ocean[");#DecValTok("5");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" ocean[");#DecValTok("1");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.7");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Valores ajustados\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Resíduos\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/fig-residuos-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Resíduos vs.~valores ajustados: uma nuvem sem padrão (sem 'funil') indica variâncias homogêneas.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-residuos>


#quote(block: true)[
#strong[Como ler.] No Q-Q plot, pontos próximos da linha indicam resíduos normais. No gráfico de resíduos vs.~ajustados, uma nuvem sem padrão indica variâncias homogêneas. Aqui, #strong[ambos os testes passam] ($p > 0 \, 05$): a ANOVA está autorizada.
]

== Onde estão as diferenças? O pós-teste de Tukey
<onde-estão-as-diferenças-o-pós-teste-de-tukey>
A ANOVA diz #strong[que existe] diferença, mas não #strong[onde]. Para descobrir quais rações diferem entre si, usamos o #strong[Tukey HSD], que compara todos os pares controlando o erro global.

#Skylighting(([#FunctionTok("flextable_ocean");#NormalTok("(");#FunctionTok("mostrar_tukey");#NormalTok("(r))");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-tukey-1.png"))

], caption: figure.caption(
position: top, 
[
Comparações múltiplas de Tukey HSD entre as rações.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-tukey>


#Skylighting(([#NormalTok("tk ");#OtherTok("<-");#NormalTok(" r");#SpecialCharTok("$");#NormalTok("tukey_df");],
[#NormalTok("tk");#SpecialCharTok("$");#NormalTok("cor ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("ifelse");#NormalTok("(tk");#SpecialCharTok("$");#NormalTok("Significativo, ocean[");#DecValTok("5");#NormalTok("], ocean[");#DecValTok("3");#NormalTok("])");],
[#FunctionTok("ggplot");#NormalTok("(tk, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Diferenca, ");#AttributeTok("y =");#NormalTok(" ");#FunctionTok("reorder");#NormalTok("(Comparacao, Diferenca))) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"grey50\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_errorbarh");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("xmin =");#NormalTok(" Lwr, ");#AttributeTok("xmax =");#NormalTok(" Upr, ");#AttributeTok("colour =");#NormalTok(" cor), ");#AttributeTok("height =");#NormalTok(" ");#FloatTok("0.25");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("colour =");#NormalTok(" cor), ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_colour_identity");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Diferença de médias (g)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comparação\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo09/anova_estudos_observacionais_experimentais_files/figure-typst/fig-tukey-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Diferença entre médias (Tukey HSD) com IC de 95%. Intervalos que cruzam o zero indicam pares sem diferença significativa.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-tukey>


== O relato automático
<o-relato-automático>
Toda essa análise se resume em uma frase científica, gerada pela função #strong[#NormalTok("relatar_anova()");] --- a mesma que entra no relatório #NormalTok(".docx"); exportado pela CatalyseR:

#quote(block: true)[
Foi realizada uma análise de variância (ANOVA) unifatorial para avaliar o efeito do fator categórico 'racao' sobre a variável numérica 'peso\_g'. Os resíduos do modelo foram avaliados e o teste de Shapiro-Wilk (W = 0,9338, p = 0,2031) passou na validação de normalidade, enquanto o teste de Bartlett (K² = 0,101, p = 0,9917) passou na validação de homocedasticidade. A ANOVA indicou um efeito estatisticamente significativo do fator sobre a resposta, F(3, 15) = 24,38, p \< 0,001. O pós-teste de comparações múltiplas de Tukey HSD identificou diferenças significativas nos pares: C-A; D-A; C-B; D-C.
]

== E daí? Da significância à decisão
<e-daí-da-significância-à-decisão>
Estatística é meio, não fim. #cite(<bhujel2011>, form: "prose") faz uma ressalva importante: a ração C dá o #strong[maior crescimento], mas a recomendação prática depende do #strong[custo]. Só vale adotar a ração mais cara se o ganho de produção pagar a diferença de preço. A significância estatística responde "há efeito?"\; a decisão de manejo precisa também de "compensa?".

#quote(block: true)[
#strong[Resumo do capítulo.] (1) Use ANOVA para comparar 3+ médias; (2) confira os pressupostos #strong[antes] de confiar no $p$\; (3) se a ANOVA for significativa, use Tukey para localizar as diferenças; (4) traduza o resultado em uma recomendação prática. No ecossistema EAPA, os passos 1--3 nascem de uma única função (#NormalTok("calcular_anova");), que serve igualmente à IDE, ao relatório #NormalTok(".docx"); e a este livro.
]

== Para praticar
<para-praticar-7>
+ Refaça a ANOVA #strong[sem] a ração C e veja se as conclusões sobre A, B e D mudam.
+ O que aconteceria com a tabela de pressupostos se um valor de C fosse, digamos, 130 g (um #emph[outlier])? Teste e interprete.
+ Troque o pós-teste de Tukey por comparações com #NormalTok("pairwise.t.test()"); e compare as conclusões.

#part[Unidade IV · Relações entre variáveis]
= Análise de Correlação e Associação entre Variáveis
<análise-de-correlação-e-associação-entre-variáveis>
Ou: quando duas medidas andam de mãos dadas --- e como saber se isso é real

\
#block[
#callout(
body: 
[
Você tem uma planilha cheia de colunas --- concentrações de íons na água, tamanhos de animais, sexo, estação do ano --- e bate aquela pergunta: #strong[o que tem a ver com o quê?] Será que, quando um íon sobe, outro acompanha? A proporção de machos e fêmeas muda entre as estações? Olhar coluna por coluna não revela essas ligações. Precisamos de ferramentas que meçam #strong[o quanto duas variáveis caminham juntas].

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Há duas perguntas parecidas, mas diferentes, escondidas aqui. A primeira é sobre #strong[correlação]: quando duas variáveis #strong[numéricas] sobem e descem juntas (ou em sentidos opostos). A segunda é sobre #strong[associação]: quando duas variáveis #strong[categóricas] aparecem juntas mais (ou menos) do que o acaso explicaria. A ferramenta muda conforme o tipo de variável --- e é fácil escolher errado. Vamos às duas.

== Parte 1 --- Correlação entre variáveis numéricas
<parte-1-correlação-entre-variáveis-numéricas>
=== Os dados: a química das salmouras
<os-dados-a-química-das-salmouras>
Para correlação, queremos variáveis que #strong[não] estejam todas amarradas pela mesma causa. Medidas de tamanho de um animal, por exemplo, sobem quase todas juntas (um bicho grande é grande em tudo) --- e a correlação fica monótona, tudo perto de 1. Já um conjunto de #strong[concentrações químicas] é mais interessante: alguns componentes se associam, outros se opõem.

Usaremos o #NormalTok("brine_carbonatos"); do #NormalTok("EAPADados");: 19 amostras de #strong[salmouras] de unidades carbonáticas, com a concentração (em ppm) de seis íons --- bicarbonato (#NormalTok("HCO3");), sulfato (#NormalTok("SO4");), cloreto (#NormalTok("Cl");), cálcio (#NormalTok("Ca");), magnésio (#NormalTok("Mg");) e sódio (#NormalTok("Na");) --- além do grupo geológico de origem. É um conjunto #strong[multivariado] que você reencontrará nos capítulos de PCA e agrupamento; aqui ele serve para enxergar como variáveis de um mesmo sistema se correlacionam.

#block[
#Skylighting(([#FunctionTok("str");#NormalTok("(brine_carbonatos)");],));
#block[
#Skylighting(([#NormalTok("'data.frame':   19 obs. of  8 variables:");],
[#NormalTok(" $ amostra: chr  \"E01\" \"E02\" \"E03\" \"E04\" ...");],
[#NormalTok(" $ grupo  : Factor w/ 3 levels \"Ellenburger_Dolomite\",..: 1 1 1 1 1 1 1 2 2 2 ...");],
[#NormalTok(" $ HCO3   : num  10.4 6.2 2.1 8.5 6.7 3.8 1.5 25.6 12 9 ...");],
[#NormalTok(" $ SO4    : num  30 29.6 11.4 22.5 32.8 ...");],
[#NormalTok(" $ Cl     : num  967 1175 2387 2186 2016 ...");],
[#NormalTok(" $ Ca     : num  95.9 111.7 348.3 339.6 287.6 ...");],
[#NormalTok(" $ Mg     : num  53.7 43.9 119.3 73.6 75.1 ...");],
[#NormalTok(" $ Na     : num  858 1055 1932 1803 1692 ...");],));
]
]
=== Por dentro da conta: o que é correlação
<por-dentro-da-conta-o-que-é-correlação>
Imagine duas medidas dançando. Se, quando uma sobe, a outra #strong[também] sobe, elas dançam no mesmo compasso --- correlação #strong[positiva]. Se uma sobe enquanto a outra desce, dançam em sentidos opostos --- correlação #strong[negativa]. Se cada uma vai para um lado sem ligar para a outra, não há correlação.

O #strong[coeficiente de correlação de Pearson] ($r$) põe número nessa dança. Ele nasce da #strong[covariância] (o quanto as duas variam juntas), só que padronizada para ficar sempre entre $- 1$ e $+ 1$:

$ r = frac(sum \( x_i - macron(x) \) \( y_i - macron(y) \), sqrt(sum \( x_i - macron(x) \)^2) #h(0em) sqrt(sum \( y_i - macron(y) \)^2)) $

O sinal diz a #strong[direção] (positiva ou negativa); o valor absoluto diz a #strong[força]: perto de $1$ (ou $- 1$), as duas medidas andam quase coladas; perto de $0$, andam soltas. Um lembrete que vale ouro: #strong[correlação não é causalidade]. Duas variáveis podem subir juntas porque uma causa a outra, porque uma terceira causa as duas, ou por pura coincidência.

=== A matriz de correlação no R
<a-matriz-de-correlação-no-r>
Com várias variáveis numéricas, calculamos a correlação de #strong[todos os pares de uma vez] --- a #emph[matriz de correlação]. Primeiro separamos só as colunas dos íons:

#block[
#Skylighting(([#NormalTok("ions ");#OtherTok("<-");#NormalTok(" brine_carbonatos[, ");#FunctionTok("c");#NormalTok("(");#StringTok("\"HCO3\"");#NormalTok(", ");#StringTok("\"SO4\"");#NormalTok(", ");#StringTok("\"Cl\"");#NormalTok(", ");#StringTok("\"Ca\"");#NormalTok(", ");#StringTok("\"Mg\"");#NormalTok(", ");#StringTok("\"Na\"");#NormalTok(")]");],
[],
[#NormalTok("M ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cor");#NormalTok("(ions, ");#AttributeTok("use =");#NormalTok(" ");#StringTok("\"complete.obs\"");#NormalTok(")   ");#CommentTok("# método de Pearson (padrão)");],));
]
#Skylighting(([#NormalTok("Mtab ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("round");#NormalTok("(M, ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("tab  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(Í");#AttributeTok("on =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(Mtab), Mtab, ");#AttributeTok("check.names =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("row.names =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(tab)");],));
#figure([
#box(image("capitulos\\capitulo10/analise_correlacao_associacao_variaveis_files/figure-typst/tbl-correlacao-1.png"))

], caption: figure.caption(
position: top, 
[
Matriz de correlação de Pearson entre as seis concentrações iônicas das salmouras.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-correlacao>


Os números variam bastante --- alguns pares quase colados, outros frouxos, e há sinais negativos. Mas tabela de correlação cansa o olho. É aí que entra o #strong[#NormalTok("corrplot");]: ele transforma a matriz num mapa de cores, onde a intensidade e o sentido da cor mostram, num relance, quem anda com quem (azul = positivo, coral = negativo).

#Skylighting(([#CommentTok("# Escala coral (negativo) -> branco -> teal (positivo). Uso o teal (ocean[2]) no");],
[#CommentTok("# topo, e nao o navy quase preto, para o numero escuro permanecer legivel mesmo");],
[#CommentTok("# nas correlacoes fortes.");],
[#NormalTok("cores ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("colorRampPalette");#NormalTok("(");#FunctionTok("c");#NormalTok("(ocean[");#DecValTok("5");#NormalTok("], ");#StringTok("\"white\"");#NormalTok(", ocean[");#DecValTok("2");#NormalTok("]))(");#DecValTok("200");#NormalTok(")");],
[#FunctionTok("corrplot");#NormalTok("(M, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"color\"");#NormalTok(", ");#AttributeTok("col =");#NormalTok(" cores, ");#AttributeTok("col.lim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#SpecialCharTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("         ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"upper\"");#NormalTok(", ");#AttributeTok("addCoef.col =");#NormalTok(" ");#StringTok("\"grey15\"");#NormalTok(",");],
[#NormalTok("         ");#AttributeTok("tl.col =");#NormalTok(" ocean[");#DecValTok("1");#NormalTok("], ");#AttributeTok("tl.srt =");#NormalTok(" ");#DecValTok("45");#NormalTok(", ");#AttributeTok("tl.cex =");#NormalTok(" ");#FloatTok("0.9");#NormalTok(",");],
[#NormalTok("         ");#AttributeTok("number.cex =");#NormalTok(" ");#FloatTok("0.8");#NormalTok(", ");#AttributeTok("diag =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(",");],
[#NormalTok("         ");#AttributeTok("mar =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok(", ");#DecValTok("0");#NormalTok("))");],));
#figure([
#box(image("capitulos\\capitulo10/analise_correlacao_associacao_variaveis_files/figure-typst/fig-corrplot-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Mapa de correlação dos íons. Tons de teal = correlação positiva; coral = negativa; a intensidade indica a força. Os números repetem o coeficiente de Pearson.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-corrplot>


#block[
#callout(
body: 
[
#strong[Do mouse ao código (e o que vem por aí).] Hoje o livro usa #NormalTok("cor()"); e #NormalTok("corrplot()"); diretamente. A correlação ainda #strong[não é uma análise canônica da CatalyseR] (a IDE usa matriz de correlação por dentro da PCA, e faz a correlação bivariada dentro da regressão). Está no backlog transformá-la numa família canônica do #NormalTok("EAPADados"); --- algo como #NormalTok("calcular_correlacao()");, #NormalTok("mostrar_correlacao()"); e #NormalTok("grafico_correlacao()"); ---, para que a IDE, o relatório #NormalTok(".docx"); e este capítulo derivem do mesmo código. Por ora, #NormalTok("corrplot()"); resolve.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Um par de perto, com teste
<um-par-de-perto-com-teste>
A matriz mostra o panorama; para #strong[um] par, o #NormalTok("cor.test()"); dá o coeficiente #strong[e] testa se ele é diferente de zero. Veja a relação entre sódio e cloreto, dois íons que costumam caminhar juntos nas salmouras:

#block[
#Skylighting(([#NormalTok("ct ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cor.test");#NormalTok("(brine_carbonatos");#SpecialCharTok("$");#NormalTok("Na, brine_carbonatos");#SpecialCharTok("$");#NormalTok("Cl)");],
[#NormalTok("ct");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's product-moment correlation");],
[],
[#NormalTok("data:  brine_carbonatos$Na and brine_carbonatos$Cl");],
[#NormalTok("t = 24.339, df = 17, p-value = 1.183e-14");],
[#NormalTok("alternative hypothesis: true correlation is not equal to 0");],
[#NormalTok("95 percent confidence interval:");],
[#NormalTok(" 0.9630053 0.9947046");],
[#NormalTok("sample estimates:");],
[#NormalTok("      cor ");],
[#NormalTok("0.9859529 ");],));
]
]
#quote(block: true)[
A correlação entre o sódio (Na) e o cloreto (Cl) foi de #emph[r] = 0.986 (IC 95% \[0.963; 0.995\]), p \< 0,001 --- uma correlação muito forte e positiva: as duas concentrações tendem a subir juntas.
]

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(brine_carbonatos, ");#FunctionTok("aes");#NormalTok("(Na, Cl, ");#AttributeTok("colour =");#NormalTok(" grupo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#FloatTok("2.5");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.8");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(", ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ocean[");#DecValTok("1");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("0.8");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_colour_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ocean[");#SpecialCharTok("-");#DecValTok("1");#NormalTok("], ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"Grupo\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Sódio (ppm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Cloreto (ppm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo10/analise_correlacao_associacao_variaveis_files/figure-typst/fig-dispersao-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Sódio vs.~cloreto nas salmouras, por grupo geológico. A reta resume a tendência linear.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-dispersao>


=== As letras miúdas: Pearson tem pressupostos
<as-letras-miúdas-pearson-tem-pressupostos>
O $r$ de Pearson mede a relação #strong[linear] e é sensível a #emph[outliers] e a relações curvas. Sempre olhe o gráfico de dispersão #strong[antes] de confiar no número: um $r$ baixo pode esconder uma relação forte, porém curva; um $r$ alto pode ser obra de um único ponto extremo. Quando a relação é monotônica mas não linear, ou há valores discrepantes, a alternativa é a correlação de #strong[Spearman] (sobre os postos), que se pede com #NormalTok("method = \"spearman\"");:

#block[
#Skylighting(([#FunctionTok("cor");#NormalTok("(brine_carbonatos");#SpecialCharTok("$");#NormalTok("Na, brine_carbonatos");#SpecialCharTok("$");#NormalTok("Cl, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"spearman\"");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.9684211");],));
]
]
== Parte 2 --- Associação entre variáveis categóricas
<parte-2-associação-entre-variáveis-categóricas>
Correlação é para número. Quando as variáveis são #strong[categóricas] --- sexo, local, estação ---, a pergunta vira: as categorias de uma se distribuem de forma #strong[dependente] das categorias da outra? A ferramenta é a #strong[tabela de contingência] e o #strong[teste qui-quadrado ($chi^2$) de independência].

=== Os dados: caranguejos de Bragança (PA)
<os-dados-caranguejos-de-bragança-pa>
O #NormalTok("biometria_caranguejos"); traz 993 caranguejos capturados em Bragança, no Pará, com sexo, local e estação anotados. Vamos perguntar: #strong[a proporção de machos e fêmeas depende da estação do ano?] (Uma pergunta com sentido biológico --- épocas reprodutivas mudam quem é capturado.)

#Skylighting(([#NormalTok("tab_cont ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(Estação ");#OtherTok("=");#NormalTok(" biometria_caranguejos");#SpecialCharTok("$");#NormalTok("Estacao,");],
[#NormalTok("                  ");#AttributeTok("Sexo    =");#NormalTok(" biometria_caranguejos");#SpecialCharTok("$");#NormalTok("Sexo)");],
[#NormalTok("cont_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame.matrix");#NormalTok("(tab_cont)");],
[#NormalTok("cont_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(Estação ");#OtherTok("=");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(cont_df), cont_df,");],
[#NormalTok("                     ");#AttributeTok("check.names =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("row.names =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(cont_df)");],));
#figure([
#box(image("capitulos\\capitulo10/analise_correlacao_associacao_variaveis_files/figure-typst/tbl-contingencia-1.png"))

], caption: figure.caption(
position: top, 
[
Tabela de contingência: número de caranguejos por estação e sexo.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-contingencia>


=== Por dentro da conta: o que o qui-quadrado compara
<por-dentro-da-conta-o-que-o-qui-quadrado-compara>
A ideia é simples e elegante. O teste calcula quantos caranguejos #strong[esperaríamos] em cada célula #strong[se] sexo e estação fossem independentes (isto é, se a proporção de machos fosse a mesma nas duas estações). Depois compara esse #strong[esperado] com o que de fato foi #strong[observado]. Quanto maior a distância entre observado e esperado, maior o $chi^2$ --- e mais difícil de explicar pelo acaso.

#block[
#Skylighting(([#NormalTok("qui ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("chisq.test");#NormalTok("(tab_cont)");],
[#NormalTok("qui");],));
#block[
#Skylighting(([],
[#NormalTok("    Pearson's Chi-squared test with Yates' continuity correction");],
[],
[#NormalTok("data:  tab_cont");],
[#NormalTok("X-squared = 112.44, df = 1, p-value < 2.2e-16");],));
]
]
#Skylighting(([#FunctionTok("ggplot");#NormalTok("(biometria_caranguejos, ");#FunctionTok("aes");#NormalTok("(Estacao, ");#AttributeTok("fill =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_bar");#NormalTok("(");#AttributeTok("position =");#NormalTok(" ");#StringTok("\"fill\"");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.9");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ocean[");#FunctionTok("c");#NormalTok("(");#DecValTok("2");#NormalTok(", ");#DecValTok("4");#NormalTok(")]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_y_continuous");#NormalTok("(");#AttributeTok("labels =");#NormalTok(" scales");#SpecialCharTok("::");#NormalTok("percent) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Estação\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Proporção\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo10/analise_correlacao_associacao_variaveis_files/figure-typst/fig-associacao-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Proporção de sexos em cada estação. Barras parecidas entre estações indicam pouca associação.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-associacao>


#quote(block: true)[
Aplicou-se o teste qui-quadrado de independência entre estação e sexo, $chi^2$\(1) = 112.44, p \< 0,001. O tamanho do efeito (V de Cramér) foi de 0.337, indicando uma associação moderada entre as duas variáveis.
]

#quote(block: true)[
#strong[Como ler.] Um $p$ pequeno (\< 0,05) diz que sexo e estação #strong[não] são independentes --- a composição de sexos muda conforme a estação. Um $p$ grande diz que não há evidência de associação. Mas atenção: com amostras grandes (aqui são quase mil), até diferenças minúsculas viram "significativas". Por isso reportamos também o #strong[V de Cramér], que mede a #strong[força] da associação numa escala de 0 a 1 --- o complemento do "tem efeito?" com o "quão grande é?".
]

== E daí? Da significância à decisão
<e-daí-da-significância-à-decisão-1>
Correlação e associação são pontos de partida, não de chegada. Uma correlação forte entre íons sugere uma origem geoquímica comum --- e adianta o que a PCA vai condensar em poucos eixos lá na frente. Já uma associação entre sexo e estação, se real, tem leitura de manejo: pode sinalizar época reprodutiva e orientar regras de defeso. Em ambos os casos, o número abre a conversa --- quem fecha é o conhecimento do sistema, da biologia e da pesca.

#quote(block: true)[
#strong[Resumo do capítulo.] (1) Variáveis #strong[numéricas] → #strong[correlação] (Pearson, ou Spearman quando a relação não é linear); a matriz vira mapa com #NormalTok("corrplot()");. (2) Variáveis #strong[categóricas] → #strong[associação] pela tabela de contingência e pelo #strong[qui-quadrado], com o #strong[V de Cramér] medindo a força. (3) Sempre #strong[veja o gráfico] antes de confiar no coeficiente. (4) Correlação e associação #strong[não são causalidade].
]

== Para praticar
<para-praticar-8>
+ Refaça a matriz de correlação #strong[sem] o íon #NormalTok("Na"); e veja se as relações entre os demais mudam de força.
+ Troque o par do #NormalTok("cor.test()"); por cálcio (#NormalTok("Ca");) e magnésio (#NormalTok("Mg");). A correlação é tão forte quanto a do par sódio-cloreto?
+ Monte uma nova tabela de contingência entre #strong[local] e #strong[sexo] (#NormalTok("biometria_caranguejos$Local");) e teste a associação. O que muda na conclusão?

= Regressão Linear Simples
<regressão-linear-simples>
Ou: traçando a reta que melhor resume a relação entre duas medidas

\
#block[
#callout(
body: 
[
Lá na Unidade II, ao explorar os caranguejos de Bragança, um gráfico nos chamou a atenção: a largura e o comprimento da carapaça subiam juntos, numa nuvem que apontava para cima. Na hora dissemos que aquilo era #emph[pista] de uma relação. Agora é hora de cumprir a promessa: traçar a #strong[reta] que resume essa relação, medir sua força e usá-la para prever. É a #strong[regressão linear simples].

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
A regressão linear simples ajusta uma #strong[reta] entre duas variáveis numéricas --- uma #strong[preditora] (o $x$, aqui a largura da carapaça, LC) e uma #strong[resposta] (o $y$, o comprimento, CC). A reta tem a forma de sempre:

$ accent(C C, ̂) = beta_0 + beta_1 dot.op L C $

em que $beta_0$ é o #strong[intercepto] (o valor de CC quando LC = 0) e $beta_1$ é a #strong[inclinação] --- o quanto o comprimento aumenta, em média, para cada milímetro a mais de largura. O método escolhe a reta que torna mínima a soma dos #strong[quadrados dos resíduos] (as distâncias verticais dos pontos à reta); por isso se chama #emph[mínimos quadrados ordinários].

== Como os dados foram medidos
<como-os-dados-foram-medidos>
Antes dos cálculos, vale ver de onde vêm os números. Em cada caranguejo-uçá capturado, mediram-se, com a ajuda de paquímetro digital, duas dimensões da carapaça --- a #strong[largura] (LC) e o #strong[comprimento] (CC), em milímetros ---, anotando ainda o #strong[local], a #strong[estação] e o #strong[sexo] (#ref(<fig-medicao>, supplement: [Figura])). Foi um estudo planejado: dois locais, duas estações e os dois sexos, com cada indivíduo virando uma linha no formato #emph[tidy].

#figure([
#box(image("capitulos\\capitulo11/../../images/esquema_medicao_caranguejo.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Esquema de medição morfométrica do caranguejo-uçá: a largura (LC) e o comprimento (CC) da carapaça, tomadas a paquímetro, e o desenho amostral (local, estação e sexo) que estrutura os dados.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-medicao>


E aqui entra uma ideia que atravessa toda a estatística: #strong[amostras diferentes dão números diferentes]. Se outra equipe medisse outro punhado de caranguejos, a reta ajustada não sairia idêntica --- o intercepto e a inclinação oscilariam um pouco. Por isso cada coeficiente vem acompanhado de um #strong[erro padrão], e a reta no gráfico vem com uma #strong[faixa de confiança]: ambos medem essa incerteza da amostragem. A reta que estimamos é a melhor aposta a partir #emph[desta] amostra --- não uma verdade cravada.

== Antes da reta: por que filtrar os dados
<antes-da-reta-por-que-filtrar-os-dados>
Há uma armadilha aqui, e ela ensina muito. Se jogarmos #strong[todos] os caranguejos num único modelo, a reta sai fraca:

#block[
#Skylighting(([#NormalTok("modelo_geral ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(CC ");#SpecialCharTok("~");#NormalTok(" LC, ");#AttributeTok("data =");#NormalTok(" biometria_caranguejos)");],
[#FunctionTok("summary");#NormalTok("(modelo_geral)");#SpecialCharTok("$");#NormalTok("r.squared");],));
#block[
#Skylighting(([#NormalTok("[1] 0.1181865");],));
]
]
Um $R^2$ de apenas #strong[0,12] --- a reta mal explica a relação. O motivo não é que largura e comprimento não se relacionem; é que a base #strong[mistura grupos heterogêneos] (estações, locais e sexos com retas diferentes), e essa mistura embaralha o padrão. Esse é um lembrete valioso: às vezes o problema não está na análise, mas em #strong[sobre quem] ela é feita. Quando subconjuntos têm comportamentos distintos, analisá-los juntos esconde o que cada um tem de claro.

Olhando por estação, a diferença salta aos olhos: na #strong[estação seca] a relação é nítida; na chuvosa, dispersa. Vamos então #strong[filtrar] os dados da estação seca e trabalhar com esse subconjunto homogêneo.

#block[
#Skylighting(([#NormalTok("caranguejos_seca ");#OtherTok("<-");#NormalTok(" biometria_caranguejos ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(Estacao ");#SpecialCharTok("==");#NormalTok(" ");#StringTok("\"Seca\"");#NormalTok(")");],
[],
[#FunctionTok("nrow");#NormalTok("(caranguejos_seca)");],));
#block[
#Skylighting(([#NormalTok("[1] 538");],));
]
]
== Ajustando a reta
<ajustando-a-reta>
Com o subconjunto em mãos, o ajuste é uma linha de código --- a função #NormalTok("lm()"); (de #emph[linear model]):

#block[
#Skylighting(([#NormalTok("modelo ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("lm");#NormalTok("(CC ");#SpecialCharTok("~");#NormalTok(" LC, ");#AttributeTok("data =");#NormalTok(" caranguejos_seca)");],
[#FunctionTok("summary");#NormalTok("(modelo)");],));
#block[
#Skylighting(([],
[#NormalTok("Call:");],
[#NormalTok("lm(formula = CC ~ LC, data = caranguejos_seca)");],
[],
[#NormalTok("Residuals:");],
[#NormalTok("    Min      1Q  Median      3Q     Max ");],
[#NormalTok("-4.0436 -0.8583  0.1108  0.9564  2.1726 ");],
[],
[#NormalTok("Coefficients:");],
[#NormalTok("             Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("(Intercept) -4.056095   0.488549  -8.302 8.36e-16 ***");],
[#NormalTok("LC           1.030877   0.007697 133.926  < 2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 1.122 on 536 degrees of freedom");],
[#NormalTok("Multiple R-squared:  0.971, Adjusted R-squared:  0.9709 ");],
[#NormalTok("F-statistic: 1.794e+04 on 1 and 536 DF,  p-value: < 2.2e-16");],));
]
]
A leitura da saída:

#Skylighting(([#NormalTok("coefs ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame");#NormalTok("(");#FunctionTok("round");#NormalTok("(");#FunctionTok("coef");#NormalTok("(");#FunctionTok("summary");#NormalTok("(modelo)), ");#DecValTok("4");#NormalTok("))");],
[#NormalTok("coefs ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cbind");#NormalTok("(");#AttributeTok("Termo =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(coefs), coefs)");],
[#FunctionTok("rownames");#NormalTok("(coefs) ");#OtherTok("<-");#NormalTok(" ");#ConstantTok("NULL");],
[#FunctionTok("flextable_ocean");#NormalTok("(coefs)");],));
#figure([
#box(image("capitulos\\capitulo11/regressao_linear_simples_multipla_files/figure-typst/tbl-coef-1.png"))

], caption: figure.caption(
position: top, 
[
Coeficientes do modelo de regressão de CC sobre LC, na estação seca.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-coef>


A #strong[inclinação] ($beta_1$) ficou em torno de #strong[1,03]: cada milímetro a mais de largura corresponde, em média, a cerca de 1,03 mm a mais de comprimento --- ou seja, a carapaça cresce quase na proporção 1:1 entre as duas dimensões. O #emph[p]-valor minúsculo confirma que a relação é real, não acaso. E o $R^2 approx 0 \, 97$ diz que a largura sozinha explica #strong[97%] da variação do comprimento --- uma reta excelente, bem diferente do modelo bagunçado da base inteira.

Com o modelo, #strong[prever] é imediato. Para um caranguejo de 70 mm de largura:

#block[
#Skylighting(([#FunctionTok("predict");#NormalTok("(modelo, ");#AttributeTok("newdata =");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("LC =");#NormalTok(" ");#DecValTok("70");#NormalTok("))");],));
#block[
#Skylighting(([#NormalTok("       1 ");],
[#NormalTok("68.10531 ");],));
]
]
== Conferindo os pressupostos
<conferindo-os-pressupostos-1>
A regressão linear confia em alguns pressupostos sobre os #strong[resíduos] --- em especial, que eles se distribuem de forma aproximadamente #strong[normal]. Um diagnóstico compacto é o #strong[gráfico quantil-quantil (Q-Q)]: se os pontos acompanham a diagonal, a normalidade se sustenta.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("residuo =");#NormalTok(" ");#FunctionTok("residuals");#NormalTok("(modelo)), ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("sample =");#NormalTok(" residuo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_qq");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("0.8");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("stat_qq_line");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Quantis teóricos\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Quantis dos resíduos\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo11/regressao_linear_simples_multipla_files/figure-typst/fig-qq-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico Q-Q dos resíduos: pontos próximos da linha indicam resíduos aproximadamente normais.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-qq>


== A reta sobre os dados
<a-reta-sobre-os-dados>
Por fim, a imagem que resume tudo: a nuvem de pontos, a reta ajustada e o #strong[intervalo de confiança de 95% da média] (a sombra azul-clara em volta da reta) --- a faixa que mede a incerteza sobre a #emph[posição da reta], estreita aqui porque o ajuste é muito bom.

#Skylighting(([#NormalTok("b   ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("coef");#NormalTok("(modelo)");],
[#NormalTok("r2  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("summary");#NormalTok("(modelo)");#SpecialCharTok("$");#NormalTok("r.squared");],
[#NormalTok("eq  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sprintf");#NormalTok("(");#StringTok("\"CC = %.2f + %.2f \\u00b7 LC");#SpecialCharTok("\\n");#StringTok("R\\u00b2 = %.3f\"");#NormalTok(", b[");#DecValTok("1");#NormalTok("], b[");#DecValTok("2");#NormalTok("], r2)");],
[],
[#FunctionTok("ggplot");#NormalTok("(caranguejos_seca, ");#FunctionTok("aes");#NormalTok("(LC, CC)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("], ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"#A6C8E0\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("min");#NormalTok("(caranguejos_seca");#SpecialCharTok("$");#NormalTok("LC), ");#AttributeTok("y =");#NormalTok(" ");#FunctionTok("max");#NormalTok("(caranguejos_seca");#SpecialCharTok("$");#NormalTok("CC),");],
[#NormalTok("           ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("vjust =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("label =");#NormalTok(" eq, ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("4");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento da carapaça (mm)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo11/regressao_linear_simples_multipla_files/figure-typst/fig-reta-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Regressão de CC sobre LC na estação seca: a reta ajustada e o intervalo de confiança de 95% da média (sombra azul-clara).
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-reta>


#quote(block: true)[
A regressão de CC sobre LC, nos caranguejos da estação seca, estimou uma inclinação de 1.031 mm de comprimento por mm de largura (intercepto -4.06), com #emph[R²] de 0.971 --- a largura da carapaça explica quase toda a variação do comprimento.
]

#block[
#callout(
body: 
[
A regressão linear simples resume a relação entre duas variáveis numéricas numa #strong[reta] de mínimos quadrados, lida por três números: o #strong[intercepto], a #strong[inclinação] (quanto $y$ muda por unidade de $x$) e o #strong[$R ²$] (quanto da variação de $y$ a reta explica). No caminho, uma lição de ouro: a base inteira dava uma reta fraca ($R ² = 0 \, 12$) porque misturava grupos distintos; #strong[filtrar] para a estação seca revelou uma relação quase perfeita ($R ² approx 0 \, 97$). E nunca pule os #strong[resíduos] --- é neles que o modelo confessa se a reta serve.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Adendo: uma reta para cada sexo
<adendo-uma-reta-para-cada-sexo>
E se machos e fêmeas tiverem retas diferentes? Basta colorir os pontos por #strong[sexo] e deixar o #NormalTok("ggplot2"); ajustar uma reta para cada grupo --- com a respectiva equação ao lado, para comparação direta.

#Skylighting(([#CommentTok("# uma regressão para cada sexo");],
[#NormalTok("eqs ");#OtherTok("<-");#NormalTok(" caranguejos_seca ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(Sexo) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_modify");#NormalTok("(");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("b0 =");#NormalTok(" ");#FunctionTok("coef");#NormalTok("(");#FunctionTok("lm");#NormalTok("(CC ");#SpecialCharTok("~");#NormalTok(" LC, .x))[");#DecValTok("1");#NormalTok("],");],
[#NormalTok("                            ");#AttributeTok("b1 =");#NormalTok(" ");#FunctionTok("coef");#NormalTok("(");#FunctionTok("lm");#NormalTok("(CC ");#SpecialCharTok("~");#NormalTok(" LC, .x))[");#DecValTok("2");#NormalTok("],");],
[#NormalTok("                            ");#AttributeTok("r2 =");#NormalTok(" ");#FunctionTok("summary");#NormalTok("(");#FunctionTok("lm");#NormalTok("(CC ");#SpecialCharTok("~");#NormalTok(" LC, .x))");#SpecialCharTok("$");#NormalTok("r.squared)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("rotulo =");#NormalTok(" ");#FunctionTok("sprintf");#NormalTok("(");#StringTok("\"%s: CC = %.2f + %.2f\\u00b7LC  (R\\u00b2 = %.3f)\"");#NormalTok(",");],
[#NormalTok("                          Sexo, b0, b1, r2))");],
[],
[#NormalTok("xr ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("min");#NormalTok("(caranguejos_seca");#SpecialCharTok("$");#NormalTok("LC); yr ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("range");#NormalTok("(caranguejos_seca");#SpecialCharTok("$");#NormalTok("CC)");],
[],
[#FunctionTok("ggplot");#NormalTok("(caranguejos_seca, ");#FunctionTok("aes");#NormalTok("(LC, CC, ");#AttributeTok("color =");#NormalTok(" Sexo, ");#AttributeTok("fill =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" xr, ");#AttributeTok("y =");#NormalTok(" yr[");#DecValTok("2");#NormalTok("], ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("vjust =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("           ");#AttributeTok("label =");#NormalTok(" eqs");#SpecialCharTok("$");#NormalTok("rotulo[");#DecValTok("1");#NormalTok("], ");#AttributeTok("color =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#StringTok("\"TEAL\"");#NormalTok("]), ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("3.5");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" xr, ");#AttributeTok("y =");#NormalTok(" yr[");#DecValTok("2");#NormalTok("] ");#SpecialCharTok("-");#NormalTok(" ");#FloatTok("0.07");#NormalTok(" ");#SpecialCharTok("*");#NormalTok(" ");#FunctionTok("diff");#NormalTok("(yr), ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("vjust =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("           ");#AttributeTok("label =");#NormalTok(" eqs");#SpecialCharTok("$");#NormalTok("rotulo[");#DecValTok("2");#NormalTok("], ");#AttributeTok("color =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#StringTok("\"CORAL\"");#NormalTok("]), ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("3.5");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento da carapaça (mm)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo11/regressao_linear_simples_multipla_files/figure-typst/fig-sexo-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Regressão de CC sobre LC por sexo, na estação seca: uma reta e uma equação para cada grupo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-sexo>


As duas retas ficam praticamente sobrepostas --- a relação entre largura e comprimento é a mesma nos dois sexos. Se divergissem, seria sinal de que o sexo muda não só o #emph[tamanho], mas a própria #emph[forma] de crescer.

#block[
#callout(
body: 
[
+ Refaça a regressão simples filtrando #NormalTok("Local == \"Caratateua\""); em vez de #NormalTok("Estacao == \"Seca\"");. O $R ²$ muda muito? Por quê?
+ Ajuste o modelo na estação #strong[chuvosa] e compare o $R ²$ e a inclinação com os da seca. O que isso sugere sobre a biologia (ou sobre a coleta)?
+ Tome duas subamostras aleatórias de 100 caranguejos da estação seca (#NormalTok("slice_sample(n = 100)");), ajuste a reta em cada uma e compare o intercepto e a inclinação. Quanto eles variam de uma amostra para a outra?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Análise de Regressão Não Linear
<análise-de-regressão-não-linear>
Ou: quando a relação entre as coisas não é uma reta

\
#block[
#callout(
body: 
[
Você mede o comprimento e o peso de vários peixes, joga tudo num gráfico e… a nuvem de pontos não sobe em linha reta: ela #strong[encurva], cada vez mais íngreme. Forçar uma reta ali seria mentir sobre a biologia. É que peso e comprimento não têm relação linear --- têm uma relação de #strong[potência]. E para ajustá-la, a régua certa não é a regressão linear, é a #strong[não linear].

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
A regressão linear assume que a resposta cresce a uma taxa constante: cada centímetro a mais soma sempre o mesmo tanto de peso. Mas um peixe não funciona assim. Ele cresce nas três dimensões ao mesmo tempo, então o peso acompanha mais ou menos o #strong[volume] --- e o volume cresce com o #strong[cubo] do comprimento. A relação peso-comprimento é o exemplo clássico de um modelo #strong[não linear nos parâmetros]:

$ W = a dot.op L^(thin b) $

em que $W$ é o peso, $L$ o comprimento, $a$ um fator de escala e $b$ o #strong[expoente de crescimento]. Quando $b = 3$, o crescimento é #strong[isométrico] (a forma do corpo não muda); quando $b$ se afasta de 3, há #strong[alometria] (o peixe vai ficando relativamente mais "gordo" ou mais "magro" à medida que cresce). Estimar $a$ e $b$ é, no fundo, ler a estratégia de crescimento do animal.

== Os dados: peso e comprimento do cangulo
<os-dados-peso-e-comprimento-do-cangulo>
O conjunto #NormalTok("cangulo_crescimento");, do pacote #NormalTok("EAPADados");, traz o comprimento (cm) e o peso (g) de cangulos ao longo de uma faixa de tamanhos. Um olhar exploratório já mostra a curva.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(cangulo_crescimento, ");#FunctionTok("aes");#NormalTok("(comprimento_cm, peso_g)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Comprimento (cm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Peso (g)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-nuvem-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Peso versus comprimento do cangulo: a relação encurva para cima, típica de um modelo de potência.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-nuvem>


#block[
#callout(
body: 
[
Um cuidado de planejamento que vale ouro neste tipo de regressão: colete peixes ao longo de uma #strong[ampla faixa de comprimentos], dos menores aos maiores que a espécie alcança. O modelo de potência descreve #emph[como o crescimento muda com o tamanho] --- e ele só consegue revelar essa curvatura se os dados a percorrerem. Uma amostra restrita a uma faixa estreita (só juvenis, ou só adultos grandes) faz a relação parecer quase reta naquele trecho, o expoente $b$ fica mal estimado e a previsão #strong[não pode ser extrapolada] para tamanhos fora do intervalo amostrado. Quanto maior a amplitude de $L$, mais fiel o ajuste representa o fenômeno biológico.

]
, 
title: 
[
Amplitude de tamanhos importa
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Ajustando o modelo de potência
<ajustando-o-modelo-de-potência>
Diferente da regressão linear, que tem fórmula fechada, a regressão não linear é #strong[iterativa]: o R parte de um chute inicial para os parâmetros e vai refinando até minimizar a soma dos quadrados dos resíduos. Por isso a função #NormalTok("nls()"); (de #emph[nonlinear least squares]) pede um argumento #NormalTok("start"); com valores iniciais razoáveis.

De onde tirar esses chutes? Há um truque elegante: #strong[linearizar]. Aplicando logaritmo nos dois lados, $W = a thin L^b$ vira $ln W = ln a + b ln L$ --- uma #strong[reta] em escala log-log. Uma regressão linear simples sobre os logaritmos nos dá, de bandeja, os valores de partida.

#block[
#Skylighting(([#CommentTok("# valores iniciais a partir da linearização log-log");],
[#NormalTok("ini ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("coef");#NormalTok("(");#FunctionTok("lm");#NormalTok("(");#FunctionTok("log");#NormalTok("(peso_g) ");#SpecialCharTok("~");#NormalTok(" ");#FunctionTok("log");#NormalTok("(comprimento_cm), ");#AttributeTok("data =");#NormalTok(" cangulo_crescimento))");],
[#NormalTok("start ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("a =");#NormalTok(" ");#FunctionTok("exp");#NormalTok("(ini[[");#DecValTok("1");#NormalTok("]]), ");#AttributeTok("b =");#NormalTok(" ini[[");#DecValTok("2");#NormalTok("]])");],
[#NormalTok("start");],));
#block[
#Skylighting(([#NormalTok("$a");],
[#NormalTok("[1] 0.03565344");],
[],
[#NormalTok("$b");],
[#NormalTok("[1] 2.858919");],));
]
]
Com os chutes em mãos, ajustamos o modelo não linear de verdade:

#block[
#Skylighting(([#NormalTok("ajuste ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nls");#NormalTok("(peso_g ");#SpecialCharTok("~");#NormalTok(" a ");#SpecialCharTok("*");#NormalTok(" comprimento_cm");#SpecialCharTok("^");#NormalTok("b,");],
[#NormalTok("              ");#AttributeTok("data =");#NormalTok(" cangulo_crescimento, ");#AttributeTok("start =");#NormalTok(" start)");],
[#FunctionTok("summary");#NormalTok("(ajuste)");],));
#block[
#Skylighting(([],
[#NormalTok("Formula: peso_g ~ a * comprimento_cm^b");],
[],
[#NormalTok("Parameters:");],
[#NormalTok("  Estimate Std. Error t value Pr(>|t|)    ");],
[#NormalTok("a 0.029516   0.002865    10.3 6.45e-08 ***");],
[#NormalTok("b 2.912868   0.026839   108.5  < 2e-16 ***");],
[#NormalTok("---");],
[#NormalTok("Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1");],
[],
[#NormalTok("Residual standard error: 11.68 on 14 degrees of freedom");],
[],
[#NormalTok("Number of iterations to convergence: 4 ");],
[#NormalTok("Achieved convergence tolerance: 4.798e-08");],));
]
]
A saída traz as estimativas: $a approx 0 \, 030$ e $b approx 2 \, 91$, ambas com erro-padrão pequeno e altamente significativas. O expoente $b = 2 \, 91$ fica #strong[muito perto de 3] --- o cangulo cresce de forma quase isométrica, com uma alometria negativa leve (engorda um pouquinho mais devagar do que o cubo do comprimento).

Como o #NormalTok("nls"); não devolve um $R^2$ no sentido tradicional, calculamos um #strong[pseudo-$R^2$] a partir da soma dos quadrados:

#block[
#Skylighting(([#NormalTok("rss ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(");#FunctionTok("residuals");#NormalTok("(ajuste)");#SpecialCharTok("^");#DecValTok("2");#NormalTok(")");],
[#NormalTok("tss ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sum");#NormalTok("((cangulo_crescimento");#SpecialCharTok("$");#NormalTok("peso_g ");#SpecialCharTok("-");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(cangulo_crescimento");#SpecialCharTok("$");#NormalTok("peso_g))");#SpecialCharTok("^");#DecValTok("2");#NormalTok(")");],
[#NormalTok("pseudo_R2 ");#OtherTok("<-");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("-");#NormalTok(" rss ");#SpecialCharTok("/");#NormalTok(" tss");],
[#FunctionTok("round");#NormalTok("(pseudo_R2, ");#DecValTok("4");#NormalTok(")");],));
#block[
#Skylighting(([#NormalTok("[1] 0.9995");],));
]
]
Um pseudo-$R^2$ de cerca de #strong[0,999] indica que o modelo de potência captura quase toda a variação do peso --- o que não surpreende, já que a relação peso-comprimento é uma das mais regulares da biologia pesqueira.

== Olhando os resíduos
<olhando-os-resíduos>
Ajustar não é o fim: é preciso checar se o modelo "sobrou" algum padrão. Os resíduos (diferença entre o peso observado e o previsto) devem se espalhar #strong[sem estrutura] em torno do zero.

#Skylighting(([#NormalTok("diag ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("ajustado =");#NormalTok(" ");#FunctionTok("fitted");#NormalTok("(ajuste),");],
[#NormalTok("                   ");#AttributeTok("residuo  =");#NormalTok(" ");#FunctionTok("residuals");#NormalTok("(ajuste))");],
[],
[#FunctionTok("ggplot");#NormalTok("(diag, ");#FunctionTok("aes");#NormalTok("(ajustado, residuo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_hline");#NormalTok("(");#AttributeTok("yintercept =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("linetype =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Peso ajustado (g)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Resíduo (g)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-residuos-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Resíduos versus valores ajustados. Sem padrão evidente --- o modelo de potência está adequado.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-residuos>


== A curva sobre os dados
<a-curva-sobre-os-dados>
Por fim, vale ver o ajuste desenhado sobre a nuvem original --- a prova visual de que a curva acompanha os pontos.

#Skylighting(([#NormalTok("ab  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("coef");#NormalTok("(ajuste)");],
[#NormalTok("eq  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("sprintf");#NormalTok("(");#StringTok("\"W = %.4f \\u00b7 L^%.3f");#SpecialCharTok("\\n");#StringTok("pseudo-R\\u00b2 = %.3f\"");#NormalTok(",");],
[#NormalTok("               ab[");#StringTok("\"a\"");#NormalTok("], ab[");#StringTok("\"b\"");#NormalTok("], pseudo_R2)");],
[],
[#FunctionTok("ggplot");#NormalTok("(cangulo_crescimento, ");#FunctionTok("aes");#NormalTok("(comprimento_cm, peso_g)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_function");#NormalTok("(");#AttributeTok("fun =");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("(L) ab[");#StringTok("\"a\"");#NormalTok("] ");#SpecialCharTok("*");#NormalTok(" L");#SpecialCharTok("^");#NormalTok("ab[");#StringTok("\"b\"");#NormalTok("],");],
[#NormalTok("                ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("min");#NormalTok("(cangulo_crescimento");#SpecialCharTok("$");#NormalTok("comprimento_cm),");],
[#NormalTok("           ");#AttributeTok("y =");#NormalTok(" ");#FunctionTok("max");#NormalTok("(cangulo_crescimento");#SpecialCharTok("$");#NormalTok("peso_g), ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("vjust =");#NormalTok(" ");#DecValTok("1");#NormalTok(",");],
[#NormalTok("           ");#AttributeTok("label =");#NormalTok(" eq, ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("], ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("4");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Comprimento (cm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Peso (g)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-ajuste-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Modelo de potência ajustado sobre os dados de peso-comprimento do cangulo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-ajuste>


#quote(block: true)[
O modelo de potência ajustado foi $hat(W) = 0.0295 dot.op L^2.913$, com pseudo-$R^2$ de 0.999. O expoente próximo de 3 indica crescimento quase isométrico do cangulo.
]

== Da linearização ao ajuste: por que não usar só os logaritmos?
<da-linearização-ao-ajuste-por-que-não-usar-só-os-logaritmos>
Você pode estar pensando: se a linearização já dá uma reta, por que não parar nela? Porque os dois caminhos #strong[minimizam coisas diferentes]. A regressão sobre os logaritmos minimiza o erro na escala #emph[log] --- tratando proporcionalmente igual um peixe de 40 g e um de 1500 g. O #NormalTok("nls"); minimiza o erro na escala #strong[original], em gramas, dando mais peso aos peixes grandes. Para a relação peso-comprimento, a versão log-linear (com a correção de viés de Baskerville) é tradicional e perfeitamente válida; o #NormalTok("nls"); é a abordagem direta quando você quer a curva que melhor prevê o peso em gramas. Conhecer as duas --- e saber que podem diferir um pouco nos parâmetros --- é o que separa quem aplica a fórmula de quem entende o que ela faz.

== Do peso à idade: o crescimento de von Bertalanffy
<do-peso-à-idade-o-crescimento-de-von-bertalanffy>
Até aqui perguntamos #emph[quanto pesa] um peixe de determinado comprimento. Falta a outra metade da história: #emph[quanto ele mede a cada idade]. E aqui o gráfico volta a encurvar --- só que por um motivo diferente.

Pense numa poupança que rende juros, mas da qual você saca um pouco mais a cada ano. No começo, o saldo dispara; depois, a retirada come quase todo o rendimento e o saldo quase para de crescer. O peixe faz algo parecido com a energia: quando jovem, investe quase tudo em ficar maior; quando adulto, divide essa energia com manutenção e reprodução, e o crescimento desacelera. O resultado é uma curva que sobe rápido, vai perdendo o fôlego e se aproxima de um teto. É exatamente isso que a função de crescimento de #strong[von Bertalanffy] descreve:

$ L_t = L_oo (1 - e^(- K thin \( t - t_0 \))) $

em que $L_t$ é o comprimento esperado na idade $t$, $L_oo$ é o #strong[comprimento assintótico] (o tamanho médio máximo para o qual a espécie tende), $K$ é o #strong[coeficiente de crescimento] e $t_0$ é a idade teórica em que o comprimento seria zero --- um ajuste de posição da curva, não um fato biológico.

Vale insistir num ponto que confunde muita gente: $K$ #strong[não] é a "velocidade" do crescimento. Ele mede a #strong[rapidez com que o peixe se aproxima de $L_oo$]. Espécies com $K$ alto chegam logo perto do teto; com $K$ baixo, crescem devagar e por mais tempo. A FAO resume bem: a curva de comprimento por idade tem inclinação cada vez menor à medida que a idade avança, encostando numa assíntota superior.#footnote[FAO --- #emph[Fitting a von Bertalanffy growth model to length-at-age data]: #link("https://www.fao.org/4/v2648e/V2648E06.htm").] E há um motivo prático para tanto cuidado com esses três números: eles alimentam modelos de avaliação de estoques, como o rendimento por recruta de Beverton e Holt --- errar o crescimento se propaga como erro na decisão de manejo.#footnote[A VBGF é base da equação de rendimento por recruta de Beverton--Holt; suposições sobre $L_oo$ afetam fortemente as estimativas de manejo. Ver verbete #emph[Von Bertalanffy function], Wikipedia: #link("https://en.wikipedia.org/wiki/Von_Bertalanffy_function").]

#block[
#callout(
body: 
[
Use quando a pergunta for #emph["como o comprimento muda com a idade (ou o tempo)?"] e os dados tiverem #strong[idade e comprimento]. Ele brilha quando o crescimento é rápido no início, desacelera com a idade e tende a um tamanho máximo --- e quando você quer #strong[comparar] crescimento entre sexos, áreas, anos ou populações. Ele é menos indicado quando a curva é fortemente #strong[sigmoide] (fases larvais, engordas curtas): aí modelos como Gompertz ou logístico costumam encaixar melhor. Nenhum modelo simples descreve todas as fases da vida de um peixe --- e tudo bem.

]
, 
title: 
[
Quando usar von Bertalanffy?
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
=== Os dados: idade e comprimento do walleye
<os-dados-idade-e-comprimento-do-walleye>
Para ajustar a curva precisamos de uma coisa nem sempre trivial: a #strong[idade] de cada peixe. Ela costuma vir de estruturas calcificadas --- os #strong[otólitos], pequenas "pedras" de carbonato de cálcio no ouvido interno dos peixes ósseos. Eles crescem a vida toda e depositam camadas sazonais; contar esses anéis é como contar os anéis de uma árvore.#footnote[NOAA Fisheries --- #emph[Age and Growth]: os otólitos são a estrutura mais usada para idade de peixes ósseos, com anéis (annuli) anuais como os de uma árvore: #link("https://www.fisheries.noaa.gov/national/science-data/age-and-growth"). Sobre a microestrutura e incrementos diários, ver FAO: #link("https://www.fao.org/4/t0529e/T0529E09.htm").] Há ainda escamas, espinhos e raios de nadadeira, além de estudos de marcação e recaptura.

O conjunto #NormalTok("walleye_erie");, do #NormalTok("EAPADados");, traz dados biológicos #strong[reais] de walleye (#emph[Sander vitreus]) do Lago Erie, com idade atribuída por otólitos, comprimento e peso --- preparado a partir de #NormalTok("FSAdata::WalleyeErie2");. É um material e tanto: permite ajustar a curva de crescimento e, depois, reaproveitar a relação peso-comprimento que vimos com o cangulo.

#Skylighting(([#NormalTok("peixes ");#OtherTok("<-");#NormalTok(" walleye_erie ");#SpecialCharTok("|>");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(idade_anos), ");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(comprimento_total_mm))");],
[],
[#FunctionTok("ggplot");#NormalTok("(peixes, ");#FunctionTok("aes");#NormalTok("(idade_anos, comprimento_total_mm)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.15");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Idade (anos)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento total (mm)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-vb-nuvem-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Comprimento por idade no walleye do Lago Erie. A nuvem sobe rápido nas idades jovens e vai achatando --- a assinatura de von Bertalanffy.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-vb-nuvem>


=== Ajustando a curva no R (e na CatalyseR)
<ajustando-a-curva-no-r-e-na-catalyser>
Como o modelo é #strong[não linear nos parâmetros], o ajuste é por mínimos quadrados não lineares, com #NormalTok("nls()"); --- a mesma família de função que a CatalyseR aciona quando você escolhe "crescimento de von Bertalanffy" no menu. O #NormalTok("nls()"); precisa de #strong[chutes iniciais]\; valores razoáveis vêm da própria biologia: $L_oo$ perto do maior comprimento observado, $K$ em torno de 0,3 por ano e $t_0$ próximo de zero.

#block[
#Skylighting(([#NormalTok("ajuste_vb ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("nls");#NormalTok("(");],
[#NormalTok("  comprimento_total_mm ");#SpecialCharTok("~");#NormalTok(" Linf ");#SpecialCharTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#SpecialCharTok("-");#NormalTok(" ");#FunctionTok("exp");#NormalTok("(");#SpecialCharTok("-");#NormalTok("K ");#SpecialCharTok("*");#NormalTok(" (idade_anos ");#SpecialCharTok("-");#NormalTok(" t0))),");],
[#NormalTok("  ");#AttributeTok("data  =");#NormalTok(" peixes,");],
[#NormalTok("  ");#AttributeTok("start =");#NormalTok(" ");#FunctionTok("list");#NormalTok("(");#AttributeTok("Linf =");#NormalTok(" ");#DecValTok("650");#NormalTok(", ");#AttributeTok("K =");#NormalTok(" ");#FloatTok("0.30");#NormalTok(", ");#AttributeTok("t0 =");#NormalTok(" ");#SpecialCharTok("-");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok(")");],
[],
[#FunctionTok("coef");#NormalTok("(ajuste_vb)");],));
#block[
#Skylighting(([#NormalTok("       Linf           K          t0 ");],
[#NormalTok("592.6578526   0.3612994  -1.5724805 ");],));
]
]
O ajuste estima um comprimento assintótico de cerca de 593 mm e um $K$ de aproximadamente 0,36 por ano. Em palavras: o walleye tende a um teto perto de 59 cm e se aproxima dele a um ritmo moderado. A curva sobre os pontos conta a história melhor que qualquer tabela:

#Skylighting(([#NormalTok("idades ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("idade_anos =");#NormalTok(" ");#FunctionTok("seq");#NormalTok("(");#FunctionTok("min");#NormalTok("(peixes");#SpecialCharTok("$");#NormalTok("idade_anos),");],
[#NormalTok("                                      ");#FunctionTok("max");#NormalTok("(peixes");#SpecialCharTok("$");#NormalTok("idade_anos), ");#AttributeTok("length.out =");#NormalTok(" ");#DecValTok("200");#NormalTok("))");],
[#NormalTok("idades");#SpecialCharTok("$");#NormalTok("ajuste ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("predict");#NormalTok("(ajuste_vb, ");#AttributeTok("newdata =");#NormalTok(" idades)");],
[],
[#FunctionTok("ggplot");#NormalTok("(peixes, ");#FunctionTok("aes");#NormalTok("(idade_anos, comprimento_total_mm)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.12");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"SEAFOAM\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_line");#NormalTok("(");#AttributeTok("data =");#NormalTok(" idades, ");#FunctionTok("aes");#NormalTok("(idade_anos, ajuste),");],
[#NormalTok("            ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("1.3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Idade (anos)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento total (mm)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-vb-curva-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Curva de von Bertalanffy ajustada sobre os comprimentos por idade do walleye.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-vb-curva>


=== Como sair a campo: o esquema de coleta
<como-sair-a-campo-o-esquema-de-coleta>
Antes do #NormalTok("nls");, vem o trabalho de obter os dados --- e o #strong[desenho] dessa coleta muda o que você pode concluir. Há dois caminhos típicos.

#figure([
#box(image("capitulos\\capitulo12/../../images/anchoveta.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Da pergunta ao banco de dados: a anatomia de um estudo de crescimento, tomando a anchoveta-do-pacífico (#emph[Engraulis ringens]) das águas centrais do Chile como exemplo real. O esquema percorre o objetivo do estudo, a origem dos dados (conjunto #NormalTok("AnchovetaChile");, do pacote #NormalTok("FSAdata");, com 207 peixes), a coleta e organização em formato #emph[tidy] --- leitura de idade, medição e uma linha por peixe ---, as variáveis resultantes (idade em meses, comprimento total e coorte) e a aplicação analítica: ajustar a curva de von Bertalanffy ao comprimento por idade. Dados de #cite(<cubillos2001>, form: "prose").
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-esquema-anchoveta>


O #strong[caminho amostral], o mais comum em biologia pesqueira, observa uma população natural ou explorada --- é o caminho que a #ref(<fig-esquema-anchoveta>, supplement: [Figura]) resume de ponta a ponta. Você amostra peixes em diferentes locais, meses ou artes de pesca; para cada um, registra comprimento, peso, sexo e maturidade, e estima a idade pelos otólitos. O fluxo é: #emph[área de estudo → amostragem em locais/meses/artes → medições + leitura de idade → banco tidy (idade | comprimento | peso | sexo | local | ano) → ajuste de von Bertalanffy]. A força aqui é o realismo; o cuidado é com a #strong[representatividade] --- se você só pega peixe grande na rede, a curva mente sobre os jovens.

O #strong[caminho experimental] é para quando você controla o ambiente --- em aquicultura, por exemplo, comparando rações, densidades ou temperaturas. Você parte de juvenis de tamanho parecido, distribui ao acaso entre as unidades, aplica os tratamentos e faz #strong[biometrias periódicas]: #emph[juvenis homogêneos → casualização nas unidades → tratamentos (ração A, B, C…) → biometria a cada 15--30 dias → banco (tanque | tempo | comprimento | peso | tratamento) → curva de crescimento ou modelo misto]. Aqui mora uma armadilha clássica: medir o mesmo tanque repetidas vezes #strong[não] gera observações independentes. Quando a ração é aplicada ao tanque inteiro, é o #strong[tanque] --- não o peixe --- que é a unidade experimental. O #NormalTok("tilapia_crescimento"); do #NormalTok("EAPADados"); ilustra justamente esse formato de peso por semana e tratamento.

=== von Bertalanffy ou modelo de potência?
<von-bertalanffy-ou-modelo-de-potência>
É comum confundir os dois, então vale fixar a diferença num quadro. O ponto-chave é que eles respondem a #strong[perguntas distintas]: von Bertalanffy descreve o crescimento #strong[no tempo]\; o modelo de potência descreve a relação #strong[peso-comprimento] num instante.

#figure([
#table(
  columns: (26%, 37%, 37%),
  align: (left,left,left,),
  table.header([Aspecto], [von Bertalanffy], [Modelo de potência],),
  table.hline(),
  [Equação], [$L_t = L_oo thin \( 1 - e^(- K \( t - t_0 \)) \)$], [$W = a thin L^(thin b)$],
  [Resposta ($y$)], [comprimento], [peso],
  [Preditora ($x$)], [idade / tempo], [comprimento],
  [Pergunta], [como cresce com a idade?], [quanto pesa em dado comprimento?],
  [Forma da curva], [assintótica], [alométrica],
  [Uso típico], [crescimento, idade, estoques], [condição corporal, biomassa],
)
], caption: figure.caption(
position: top, 
[
Dois modelos não lineares para o crescimento de peixes --- quando o eixo é a idade, von Bertalanffy; quando é o comprimento, potência.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-vb-potencia>


A melhor parte é que os dois se encaixam num #strong[encadeamento]. Primeiro, a idade prevê o comprimento (von Bertalanffy); depois, o comprimento prevê o peso (potência). Juntando as peças, vamos da #emph[idade] à #emph[biomassa]:

$ upright("idade") #h(0em) arrow.r^(upright("von Bertalanffy")) #h(0em) upright("comprimento") #h(0em) arrow.r^(upright("potência")) #h(0em) upright("peso") $

Não precisamos modelar o peso direto pela idade: modelamos o comprimento pela idade e usamos a relação peso-comprimento para chegar ao peso. É o tipo de raciocínio que sustenta uma avaliação de estoque inteira.

#block[
#callout(
body: 
[
Para a curva idade-comprimento, o #NormalTok("EAPADados"); já traz dois conjuntos #strong[reais], com procedência: #NormalTok("walleye_erie"); (#emph[Sander vitreus], Lago Erie, de #NormalTok("FSAdata::WalleyeErie2");) e #NormalTok("snapper_hg"); (#emph[Pagrus auratus], idade por otólitos, de #NormalTok("FSAdata::SnapperHG1");). Para a relação peso-comprimento, use o #NormalTok("cangulo_crescimento"); (#emph[Balistes vetula]). E quando precisar de #strong[parâmetros já publicados] ($L_oo$, $K$, $t_0$) para comparar espécies, o #link("https://www.fishbase.se")[FishBase] reúne estimativas da literatura --- ótimo para conferir se o seu ajuste faz sentido biológico, ainda que traga os parâmetros prontos, não os dados brutos de idade-comprimento.

]
, 
title: 
[
Dados confiáveis para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Do tamanho à maturidade: a regressão logística
<do-tamanho-à-maturidade-a-regressão-logística>
As duas curvas anteriores respondiam com #strong[números]: quantos centímetros a cada idade, quantos gramas a cada comprimento. Mas há uma pergunta de manejo igualmente importante cuja resposta é um #strong[sim ou não]: este peixe já se reproduz? Abaixo de certo tamanho, quase nenhuma fêmea desovou; acima dele, quase todas. No meio, é uma transição. E a pergunta que interessa não é sobre um indivíduo, e sim sobre a população: #emph[a partir de que comprimento metade das fêmeas já está madura?] Esse comprimento tem nome --- $L_50$ --- e é um dos números mais usados para regular a pesca.#footnote[O comprimento de primeira maturação ($L_50$) é base para definir tamanho mínimo de captura e malha de rede, deixando o peixe desovar ao menos uma vez antes de ser capturado. Ver King, M. (2007). #emph[Fisheries Biology, Assessment and Management], 2ª ed., Blackwell.]

O problema é que não dá para traçar uma reta --- nem uma curva de crescimento --- por cima de uma coluna de zeros e uns. Precisamos de uma curva que viva entre 0 e 1, porque o que ela devolve é uma #strong[probabilidade]: a chance de o peixe estar maduro em cada comprimento. Essa curva é a #strong[logística]:

$ p \( L \) = frac(1, 1 + e^(- \( beta_0 + beta_1 L \))) $

em que $p \( L \)$ é a probabilidade de estar maduro no comprimento $L$. Repare que ela é parente próxima da reta: por dentro mora $beta_0 + beta_1 L$, uma equação linear, que a função logística "amassa" para dentro do intervalo de 0 a 1. Por isso a logística pertence à família dos #strong[modelos lineares generalizados] (os GLM) --- é uma reta vista através de uma lente que a curva em #strong[S].

Pense num #strong[dimmer] de luz. No fundo, escuro: probabilidade quase zero de estar maduro. No topo, luz plena: quase certeza. No meio do giro, a luz muda depressa de fraca para forte --- e é nesse meio que está a informação. O $beta_1$ diz quão abrupta é a virada: alto, a transição de imaturo para maduro acontece numa faixa estreita de comprimento; baixo, ela se espalha. E o ponto em que a luz está exatamente pela metade --- probabilidade 0,5 --- é o $L_50$, que sai direto dos coeficientes:

$ L_50 = - beta_0 / beta_1 $

=== Os dados: maturidade do walleye
<os-dados-maturidade-do-walleye>
Não precisamos de um conjunto novo: o mesmo #NormalTok("walleye_erie"); que ajustou a curva de von Bertalanffy traz, para cada peixe, a condição de maturidade (#NormalTok("maturidade");, com os níveis #emph[imaturo] e #emph[maduro]). Criamos uma coluna binária --- 1 para maduro, 0 para imaturo --- e olhamos a proporção de maduros por faixa de comprimento. O #strong[S] aparece sozinho.

#Skylighting(([#NormalTok("props ");#OtherTok("<-");#NormalTok(" peixes_mat ");#SpecialCharTok("|>");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("faixa =");#NormalTok(" ggplot2");#SpecialCharTok("::");#FunctionTok("cut_width");#NormalTok("(comprimento_total_mm, ");#AttributeTok("width =");#NormalTok(" ");#DecValTok("30");#NormalTok(")) ");#SpecialCharTok("|>");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("group_by");#NormalTok("(faixa) ");#SpecialCharTok("|>");],
[#NormalTok("  dplyr");#SpecialCharTok("::");#FunctionTok("summarise");#NormalTok("(");#AttributeTok("centro =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(comprimento_total_mm),");],
[#NormalTok("                   ");#AttributeTok("prop   =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(madura),");],
[#NormalTok("                   ");#AttributeTok("n      =");#NormalTok(" dplyr");#SpecialCharTok("::");#FunctionTok("n");#NormalTok("(), ");#AttributeTok(".groups =");#NormalTok(" ");#StringTok("\"drop\"");#NormalTok(")");],
[],
[#FunctionTok("ggplot");#NormalTok("(props, ");#FunctionTok("aes");#NormalTok("(centro, prop)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("size =");#NormalTok(" n), ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Comprimento total (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Proporção de maduros\"");#NormalTok(", ");#AttributeTok("size =");#NormalTok(" ");#StringTok("\"n\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-prop-mat-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Proporção de walleyes maduros por faixa de comprimento. A subida em S é a assinatura da resposta binária.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-prop-mat>


=== Ajustando a ogiva no R (e na CatalyseR)
<ajustando-a-ogiva-no-r-e-na-catalyser>
Como a resposta é sim/não, o ajuste não é com #NormalTok("nls()");, e sim com #NormalTok("glm()"); na família #strong[binomial] --- a mesma rotina que a CatalyseR aciona quando você pede a "ogiva de maturidade". O #NormalTok("family = binomial"); é o que diz ao R: ajuste a curva em S, não uma reta.

#block[
#Skylighting(([#NormalTok("ajuste_log ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("glm");#NormalTok("(madura ");#SpecialCharTok("~");#NormalTok(" comprimento_total_mm,");],
[#NormalTok("                  ");#AttributeTok("data =");#NormalTok(" peixes_mat, ");#AttributeTok("family =");#NormalTok(" binomial)");],
[],
[#FunctionTok("coef");#NormalTok("(ajuste_log)");],));
#block[
#Skylighting(([#NormalTok("         (Intercept) comprimento_total_mm ");],
[#NormalTok("         -8.23660862           0.02166089 ");],));
]
]
Os coeficientes, sozinhos, dizem pouco. O que se lê é o $L_50 = - beta_0 \/ beta_1$, que aqui dá cerca de #strong[380 mm] (uns 38,0 cm): abaixo desse comprimento, a maioria dos walleyes ainda não se reproduziu; acima, a maioria já. Por simetria, em torno de #strong[516 mm] praticamente todos já estão maduros. A curva sobre as proporções observadas confirma o ajuste:

#Skylighting(([#NormalTok("grade ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("comprimento_total_mm =");],
[#NormalTok("                      ");#FunctionTok("seq");#NormalTok("(");#FunctionTok("min");#NormalTok("(peixes_mat");#SpecialCharTok("$");#NormalTok("comprimento_total_mm),");],
[#NormalTok("                          ");#FunctionTok("max");#NormalTok("(peixes_mat");#SpecialCharTok("$");#NormalTok("comprimento_total_mm), ");#AttributeTok("length.out =");#NormalTok(" ");#DecValTok("200");#NormalTok("))");],
[#NormalTok("grade");#SpecialCharTok("$");#NormalTok("prob ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("predict");#NormalTok("(ajuste_log, ");#AttributeTok("newdata =");#NormalTok(" grade, ");#AttributeTok("type =");#NormalTok(" ");#StringTok("\"response\"");#NormalTok(")");],
[],
[#FunctionTok("ggplot");#NormalTok("(props, ");#FunctionTok("aes");#NormalTok("(centro, prop)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("size =");#NormalTok(" n), ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"SEAFOAM\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_line");#NormalTok("(");#AttributeTok("data =");#NormalTok(" grade, ");#FunctionTok("aes");#NormalTok("(comprimento_total_mm, prob),");],
[#NormalTok("            ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("1.3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_vline");#NormalTok("(");#AttributeTok("xintercept =");#NormalTok(" L50, ");#AttributeTok("linetype =");#NormalTok(" ");#DecValTok("2");#NormalTok(", ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"AMBER\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("annotate");#NormalTok("(");#StringTok("\"text\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" L50, ");#AttributeTok("y =");#NormalTok(" ");#FloatTok("0.1");#NormalTok(", ");#AttributeTok("hjust =");#NormalTok(" ");#SpecialCharTok("-");#FloatTok("0.1");#NormalTok(",");],
[#NormalTok("           ");#AttributeTok("label =");#NormalTok(" ");#FunctionTok("sprintf");#NormalTok("(");#StringTok("\"L50 = %.0f mm\"");#NormalTok(", L50), ");#AttributeTok("colour =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Comprimento total (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Proporção / probabilidade de maduro\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("size =");#NormalTok(" ");#StringTok("\"n\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo12/analise_regressao_nao_linear_files/figure-typst/fig-ogiva-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Ogiva de maturidade ajustada (curva logística) sobre as proporções observadas, com o L50 destacado.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-ogiva>


#quote(block: true)[
A ogiva de maturidade estimou um $L_50$ de aproximadamente 380 mm (cerca de 38,0 cm) para o walleye --- o comprimento em que metade da população já se reproduziu.
]

#block[
#callout(
body: 
[
Use sempre que a resposta for #strong[binária] --- maduro/imaturo, presente/ausente, recapturado/não --- e a pergunta for #emph["qual a probabilidade de acontecer isto, dado o tamanho (ou a idade)?"]. Um cuidado decisivo: a amostra precisa ter peixes #strong[dos dois lados] da transição, pequenos e grandes; se só houver adultos, a curva não enxerga a subida e o $L_50$ vira chute. E não confunda significância com efeito --- o que move o manejo é o #strong[valor] do $L_50$ (e seu intervalo), não o #emph[p] do coeficiente. Trocando o comprimento pela idade (#NormalTok("madura ~ idade_anos");), a mesma curva entrega o $A_50$, a idade de primeira maturação.

]
, 
title: 
[
Quando usar a logística?
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
A logística fecha a trinca de modelos não lineares deste capítulo. Da idade ao comprimento (von Bertalanffy), do comprimento ao peso (potência) e, agora, do comprimento à probabilidade de já estar reproduzindo (logística) --- três perguntas, três curvas, o mesmo peixe.

#block[
#callout(
body: 
[
Nem toda relação é uma reta. A relação peso-comprimento dos peixes é uma #strong[potência], $W = a thin L^b$, em que o expoente $b$ revela a estratégia de crescimento (perto de 3, isométrico). Ajustamos modelos assim com #NormalTok("nls()");, que é iterativo e por isso pede valores iniciais --- obtidos com elegância pela #strong[linearização log-log]. Depois do ajuste, lemos os parâmetros, calculamos um pseudo-$R^2$ e, sobretudo, #strong[olhamos os resíduos] para confirmar que nenhum padrão ficou de fora. No cangulo, o modelo explicou quase toda a variação do peso, com $b$ pertinho de 3. E conhecemos um segundo modelo não linear --- a curva de #strong[von Bertalanffy], $L_t = L_oo \( 1 - e^(- K \( t - t_0 \)) \)$ ---, que descreve o comprimento ao longo da #strong[idade] e se encadeia com a potência: a idade prevê o comprimento, e o comprimento prevê o peso. Por fim, quando a resposta é um #strong[sim ou não] --- maduro ou imaturo ---, a régua é a #strong[regressão logística], uma curva em S ajustada com #NormalTok("glm(..., family = binomial)");, da qual lemos o $L_50$, o comprimento de primeira maturação que ancora o tamanho mínimo de captura.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Compare os parâmetros do #NormalTok("nls"); com os da linearização (#NormalTok("lm(log(peso_g) ~ log(comprimento_cm))");). Quão diferentes ficaram $a$ e $b$?
+ Use o modelo ajustado para prever o peso de um cangulo de 25 cm. Confira com #NormalTok("predict(ajuste, newdata = data.frame(comprimento_cm = 25))");.
+ Ajuste um modelo de potência separado para cada réplica de peso (#NormalTok("p1");, #NormalTok("p2");, #NormalTok("p3");). Os expoentes $b$ ficam parecidos?
+ Ajuste a curva de von Bertalanffy ao #NormalTok("snapper_hg"); (#NormalTok("comprimento_cm ~ idade_anos");) e compare o $L_oo$ com o do walleye. Qual espécie tende ao maior tamanho?
+ Ajuste a ogiva de maturidade do walleye usando a #strong[idade] (#NormalTok("madura ~ idade_anos");) e obtenha o $A_50$. Compare a distribuição de comprimentos da amostra com o $L_50$: a rede estaria capturando peixes abaixo do comprimento de primeira maturação?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Análise Multivariada de Dados
<análise-multivariada-de-dados>
Componentes principais (PCA) e agrupamento hierárquico --- enxergar o padrão em muitas variáveis de uma vez

\
#block[
#callout(
body: 
[
No capítulo anterior você viu que os íons das salmouras se correlacionam de formas diferentes --- alguns sobem juntos, outros se opõem. Mas correlação é coisa de #strong[par a par]. E quando você quer enxergar o padrão de #strong[todas as seis variáveis ao mesmo tempo], e ainda descobrir quais amostras se parecem entre si? Olhar seis colunas de números não resolve. Precisamos condensar e agrupar.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Quando há muitas variáveis numéricas correlacionadas, duas perguntas se impõem. A primeira: dá para #strong[resumir] essas seis colunas em dois ou três "eixos" que guardem quase toda a informação? É a #strong[Análise de Componentes Principais (PCA)]. A segunda: dá para #strong[agrupar] as amostras parecidas em famílias? É a #strong[Análise de Agrupamento Hierárquico (AAH/HCA)], que termina num #strong[dendrograma]. As duas são análises do menu da CatalyseR (módulos PCA e HCA) --- aqui o livro as reproduz com os pacotes #strong[FactoMineR] @le2008 e #strong[factoextra] @kassambara2017, que entregam gráficos bonitos e didáticos.

== Os dados: a química das salmouras (de novo)
<os-dados-a-química-das-salmouras-de-novo>
Retomamos o #NormalTok("brine_carbonatos"); @davis2002: 19 amostras de salmouras de #strong[três] unidades carbonáticas (Ellenburger Dolomite, Grayburg Dolomite e Viola Limestone), descritas por seis íons em ppm. É o mesmo conjunto da correlação --- e a documentação do dado o aproxima de algo bem familiar à aquicultura: #strong[monitoramento de qualidade de água], onde também medimos vários íons por ponto de coleta.

Há um detalhe que decide tudo na PCA: os íons estão em #strong[escalas muito diferentes].

#block[
#Skylighting(([#FunctionTok("round");#NormalTok("(");#FunctionTok("sapply");#NormalTok("(ions, sd), ");#DecValTok("1");#NormalTok(")   ");#CommentTok("# desvios-padrão por íon");],));
#block[
#Skylighting(([#NormalTok(" HCO3   SO4    Cl    Ca    Mg    Na ");],
[#NormalTok("  6.4  37.7 995.3 151.7  54.6 856.6 ");],));
]
]
O cloreto e o sódio variam em centenas; o sulfato, em poucas unidades. Se rodássemos a PCA sobre os números crus, ela enxergaria quase só o Cl e o Na --- os de maior magnitude. Por isso vamos #strong[padronizar] (cada variável com média 0 e desvio 1), o que equivale a rodar a PCA sobre a #strong[matriz de correlação].

== Parte 1 --- Componentes Principais (PCA)
<parte-1-componentes-principais-pca>
=== Por dentro da conta
<por-dentro-da-conta>
Imagine a nuvem de 19 amostras flutuando num espaço de seis dimensões --- uma por íon. Impossível de visualizar. A PCA procura o #strong[melhor ângulo de fotografia] dessa nuvem: a direção em que os pontos mais se espalham vira o #strong[primeiro componente] (PC1); a melhor direção perpendicular a ela, o #strong[segundo] (PC2); e assim por diante. Cada componente é uma combinação das variáveis originais, e a cada um corresponde um #strong[autovalor] --- quanto da variação total ele captura.

Em geral bastam os primeiros componentes para resumir quase tudo. Para decidir quantos manter, usamos dois critérios clássicos: o #strong[critério de Kaiser] (ficar com componentes de autovalor maior que 1, sobre dados padronizados) e a #strong[proporção acumulada] de variância explicada.

=== A PCA no R, com FactoMineR
<a-pca-no-r-com-factominer>
#block[
#Skylighting(([#NormalTok("res.pca ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("PCA");#NormalTok("(ions, ");#AttributeTok("scale.unit =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("graph =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],));
]
O #NormalTok("scale.unit = TRUE"); é a padronização de que falamos --- a #strong[mesma] escolha que o módulo PCA da CatalyseR oferece (a caixinha "Padronizar variáveis"), e que ela usa para montar o relatório #NormalTok(".docx");. Uma definição, vários consumidores.

#Skylighting(([#NormalTok("eig ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("get_eigenvalue");#NormalTok("(res.pca)");],
[#NormalTok("tab ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("Componente =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(eig),");],
[#NormalTok("  ");#AttributeTok("Autovalor  =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(eig[, ");#StringTok("\"eigenvalue\"");#NormalTok("], ");#DecValTok("3");#NormalTok("),");],
[#NormalTok("  ");#StringTok("\"Variância (%)\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("round");#NormalTok("(eig[, ");#StringTok("\"variance.percent\"");#NormalTok("], ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("  ");#StringTok("\"Acumulada (%)\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("round");#NormalTok("(eig[, ");#StringTok("\"cumulative.variance.percent\"");#NormalTok("], ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("  ");#AttributeTok("check.names =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("row.names =");#NormalTok(" ");#ConstantTok("NULL");],
[#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(tab)");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/tbl-eigen-1.png"))

], caption: figure.caption(
position: top, 
[
Autovalores e variância explicada por componente. Pelo critério de Kaiser, ficamos com os componentes de autovalor \> 1.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-eigen>


#Skylighting(([#FunctionTok("fviz_eig");#NormalTok("(res.pca, ");#AttributeTok("addlabels =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(",");],
[#NormalTok("         ");#AttributeTok("barfill =");#NormalTok(" ocean[");#DecValTok("3");#NormalTok("], ");#AttributeTok("barcolor =");#NormalTok(" ocean[");#DecValTok("2");#NormalTok("],");],
[#NormalTok("         ");#AttributeTok("linecolor =");#NormalTok(" ocean[");#DecValTok("5");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Componente principal\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Variância explicada (%)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/fig-scree-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Scree plot: a variância explicada cai rápido após os primeiros componentes --- sinal de que poucos eixos resumem bem os dados.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-scree>


=== O que cada componente significa: o círculo de correlações
<o-que-cada-componente-significa-o-círculo-de-correlações>
As #strong[cargas] dizem o quanto cada íon "puxa" cada componente. O círculo de correlações mostra isso de um golpe: setas no mesmo sentido indicam variáveis que andam juntas; setas opostas, variáveis que se contrapõem; setas longas (perto da borda) são as bem representadas pelos dois primeiros eixos.

#Skylighting(([#FunctionTok("fviz_pca_var");#NormalTok("(res.pca, ");#AttributeTok("col.var =");#NormalTok(" ");#StringTok("\"cos2\"");#NormalTok(", ");#AttributeTok("repel =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(",");],
[#NormalTok("             ");#AttributeTok("gradient.cols =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(ocean[");#DecValTok("3");#NormalTok("], ocean[");#DecValTok("4");#NormalTok("], ocean[");#DecValTok("5");#NormalTok("])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/fig-var-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Círculo de correlações. A cor (cos²) indica a qualidade de representação de cada íon no plano PC1--PC2.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-var>


=== O biplot: amostras e variáveis no mesmo gráfico
<o-biplot-amostras-e-variáveis-no-mesmo-gráfico>
O #strong[biplot] é o retrato-síntese da PCA: põe as #strong[amostras] (pontos) e as #strong[variáveis] (setas) no mesmo plano. Pontos próximos são amostras parecidas; uma amostra puxada na direção de uma seta tem valor alto naquele íon. Colorimos por unidade geológica para ver se a química separa as rochas.

#Skylighting(([#FunctionTok("fviz_pca_biplot");#NormalTok("(res.pca,");],
[#NormalTok("                ");#AttributeTok("geom.ind =");#NormalTok(" ");#StringTok("\"point\"");#NormalTok(", ");#AttributeTok("pointshape =");#NormalTok(" ");#DecValTok("21");#NormalTok(", ");#AttributeTok("pointsize =");#NormalTok(" ");#FloatTok("2.8");#NormalTok(",");],
[#NormalTok("                ");#AttributeTok("fill.ind =");#NormalTok(" grupo, ");#AttributeTok("col.ind =");#NormalTok(" ");#StringTok("\"grey30\"");#NormalTok(",");],
[#NormalTok("                ");#AttributeTok("addEllipses =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("ellipse.type =");#NormalTok(" ");#StringTok("\"convex\"");#NormalTok(",");],
[#NormalTok("                ");#AttributeTok("palette =");#NormalTok(" grupo_cores,");],
[#NormalTok("                ");#AttributeTok("col.var =");#NormalTok(" ocean[");#DecValTok("1");#NormalTok("], ");#AttributeTok("label =");#NormalTok(" ");#StringTok("\"var\"");#NormalTok(", ");#AttributeTok("repel =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(",");],
[#NormalTok("                ");#AttributeTok("legend.title =");#NormalTok(" ");#StringTok("\"Unidade\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/fig-biplot-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Biplot da PCA (PC1 × PC2). Pontos = amostras (por unidade); setas = íons. Os envoltórios agrupam cada unidade geológica.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-biplot>


Repare como os dois primeiros componentes já contam boa parte da história: as unidades ocupam regiões distintas do plano, e as setas mostram #strong[quais] íons puxam cada grupo. É a "fotografia" de seis dimensões reduzida a uma folha de papel.

== Parte 2 --- Agrupamento Hierárquico (dendrograma)
<parte-2-agrupamento-hierárquico-dendrograma>
A PCA resume as variáveis; a #strong[AAH] organiza as #strong[amostras]. A ideia é começar com cada amostra sozinha e ir juntando, passo a passo, as mais parecidas, até formar uma única família --- registrando a história num #strong[dendrograma] (uma árvore). Onde cortamos a árvore define quantos grupos teremos.

Medimos a "parecença" pela #strong[distância euclidiana] sobre os dados #strong[padronizados] (a mesma padronização da PCA), e juntamos os grupos pelo método de #strong[Ward], que tende a formar grupos compactos.

#block[
#Skylighting(([#NormalTok("d  ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("dist");#NormalTok("(");#FunctionTok("scale");#NormalTok("(ions))               ");#CommentTok("# distâncias sobre dados padronizados");],
[#NormalTok("hc ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("hclust");#NormalTok("(d, ");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"ward.D2\"");#NormalTok(")   ");#CommentTok("# agrupamento de Ward");],));
]
#Skylighting(([#FunctionTok("fviz_dend");#NormalTok("(hc, ");#AttributeTok("k =");#NormalTok(" ");#DecValTok("3");#NormalTok(", ");#AttributeTok("cex =");#NormalTok(" ");#FloatTok("0.7");#NormalTok(",");],
[#NormalTok("          ");#AttributeTok("k_colors =");#NormalTok(" grupo_cores,");],
[#NormalTok("          ");#AttributeTok("color_labels_by_k =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(",");],
[#NormalTok("          ");#AttributeTok("rect =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("rect_fill =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(", ");#AttributeTok("rect_border =");#NormalTok(" grupo_cores,");],
[#NormalTok("          ");#AttributeTok("main =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("ylab =");#NormalTok(" ");#StringTok("\"Distância (Ward)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/fig-dendrograma-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Dendrograma das salmouras (distância euclidiana, ligação de Ward). O corte em três grupos é destacado pelos retângulos.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-dendrograma>


O dendrograma sugere três famílias naturais. Será que elas correspondem às três unidades geológicas? A tabela cruza o grupo do corte com a unidade real:

#Skylighting(([#NormalTok("clusters ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cutree");#NormalTok("(hc, ");#AttributeTok("k =");#NormalTok(" ");#DecValTok("3");#NormalTok(")");],
[#NormalTok("cl ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("table");#NormalTok("(");#AttributeTok("Grupo =");#NormalTok(" clusters, ");#AttributeTok("Unidade =");#NormalTok(" grupo)");],
[#NormalTok("cl_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("as.data.frame.matrix");#NormalTok("(cl)");],
[#NormalTok("cl_df ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("data.frame");#NormalTok("(");#AttributeTok("Grupo =");#NormalTok(" ");#FunctionTok("rownames");#NormalTok("(cl_df), cl_df, ");#AttributeTok("check.names =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("row.names =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(")");],
[#FunctionTok("flextable_ocean");#NormalTok("(cl_df)");],));
#figure([
#box(image("capitulos\\capitulo13/analise_multivariada_dados_files/figure-typst/tbl-clusters-1.png"))

], caption: figure.caption(
position: top, 
[
Grupos do dendrograma (corte em k = 3) versus a unidade geológica real de cada amostra.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-clusters>


Quando os grupos do dendrograma "casam" com as unidades, é um forte sinal de que a química da água carrega a assinatura da rocha de origem --- o tipo de validação que a AAH oferece quando há um rótulo conhecido para conferir.

== E daí? Da multivariada à decisão
<e-daí-da-multivariada-à-decisão>
PCA e AAH não são truques de gráfico; são formas de #strong[ver o que muitas variáveis dizem juntas]. Na geoquímica, separam águas por origem. Na aquicultura, o mesmo ferramental ataca dados de #strong[qualidade de água] (oxigênio, pH, amônia, íons): a PCA aponta quais variáveis comandam a variação entre tanques, e a AAH agrupa pontos de coleta com perfis parecidos --- útil para monitorar, comparar e decidir onde intervir. O número condensa; a interpretação, guiada pelo conhecimento do sistema, é que vira manejo.

#quote(block: true)[
#strong[Resumo do capítulo.] (1) Com muitas variáveis correlacionadas, #strong[padronize] e use a #strong[PCA] para resumir em poucos componentes (critério de Kaiser, variância acumulada). (2) Leia o #strong[círculo de correlações] (o que cada eixo significa) e o #strong[biplot] (amostras + variáveis juntas). (3) Use a #strong[AAH] e o #strong[dendrograma] para agrupar amostras parecidas; valide os grupos contra um rótulo conhecido quando houver. (4) PCA e AAH são canônicas na CatalyseR (módulos PCA e HCA) --- aqui visualizadas com FactoMineR e factoextra @kassambara2017.
]

== Para praticar
<para-praticar-11>
+ Rode a PCA #strong[sem padronizar] (#NormalTok("scale.unit = FALSE");) e compare o biplot com o padronizado. Quem domina os eixos agora?
+ Corte o dendrograma em #NormalTok("k = 2"); (#NormalTok("cutree(hc, k = 2)");) e refaça a tabela de grupos. Duas unidades se fundem --- quais?
+ Troque a ligação de Ward por #NormalTok("\"complete\""); em #NormalTok("hclust()"); e veja se o dendrograma conta a mesma história.

#part[Unidade V · Visualização e comunicação de dados]
= Criando Gráficos: a galeria da visualização
<criando-gráficos-a-galeria-da-visualização>
Ou: cada pergunta tem o seu gráfico --- e o R desenha todos

\
#block[
#callout(
body: 
[
Você tem os dados na mão, a análise pronta, e na hora de mostrar o resultado bate a dúvida: barras ou linhas? pizza ou colunas? Escolher o gráfico errado é como contar uma boa história no tom errado --- a informação está lá, mas ninguém entende. Este capítulo é um catálogo prático: para cada pergunta, o gráfico certo e o código que o desenha.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Na Unidade II, os gráficos foram #strong[pistas] --- o histograma sussurrando normalidade, o boxplot insinuando diferença de médias. Aqui o objetivo é outro: #strong[comunicar]. É o mesmo espírito do menu #emph[Visualizando Dados] da IDE CatalyseR, que monta gráfico de dispersão, de linhas e de barras apontando e clicando --- e entrega o código #NormalTok("ggplot2"); por trás. Vamos percorrer essa galeria e ampliá-la, agrupando os gráficos pela #strong[pergunta] que cada um responde.

Todos seguem a mesma gramática do #NormalTok("ggplot2");: você começa com os dados e um #NormalTok("aes()"); (o que vai em cada eixo, cor, grupo), e empilha #strong[camadas] (#NormalTok("geom_*");) com #NormalTok("+");. Trocar o tipo de gráfico é, quase sempre, trocar uma camada.

== A distribuição de uma variável
<a-distribuição-de-uma-variável>
Quando a pergunta é "como esses valores se espalham?", o gráfico fala de #strong[forma]: simetria, caudas, picos.

O #strong[histograma] divide a variável em faixas e conta quantas observações caem em cada uma.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(biometria_caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" LC)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_histogram");#NormalTok("(");#AttributeTok("bins =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Frequência\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-hist-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Histograma da largura da carapaça dos caranguejos.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-hist>


A #strong[curva de densidade] é a versão suavizada do histograma --- boa para comparar a forma de dois grupos sobrepostos.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(biometria_caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" LC, ");#AttributeTok("fill =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_density");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.5");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Densidade\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-densidade-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Densidade da largura por sexo: a forma das duas distribuições, lado a lado.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-densidade>


O #strong[boxplot] resume a distribuição em cinco números (mínimo, quartis, máximo) e destaca os possíveis #emph[outliers]\; o #strong[gráfico de violino] acrescenta a forma da densidade às laterais. Ambos brilham na comparação entre grupos.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(biometria_caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Sexo, ");#AttributeTok("y =");#NormalTok(" LC, ");#AttributeTok("fill =");#NormalTok(" Sexo)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_violin");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.15");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(", ");#AttributeTok("outlier.size =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-violino-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Violino com boxplot embutido: distribuição da largura por sexo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-violino>


== A relação entre duas variáveis
<a-relação-entre-duas-variáveis>
Quando a pergunta é "uma anda com a outra?", o gráfico fala de #strong[associação].

O #strong[gráfico de dispersão] (o primeiro do menu da IDE) põe uma variável em cada eixo e desenha um ponto por observação. Uma reta de tendência ajuda a enxergar o padrão.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(biometria_caranguejos, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" LC, ");#AttributeTok("y =");#NormalTok(" CC)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_smooth");#NormalTok("(");#AttributeTok("method =");#NormalTok(" ");#StringTok("\"lm\"");#NormalTok(", ");#AttributeTok("se =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Largura da carapaça (mm)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Comprimento da carapaça (mm)\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-dispersao-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Dispersão de largura versus comprimento da carapaça, com reta de tendência.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-dispersao>


Quando há #strong[muitas] variáveis numéricas, o #strong[mapa de calor] (#emph[heatmap]) das correlações mostra, num relance, quais andam juntas: cores quentes para correlação positiva, frias para negativa.

#Skylighting(([#NormalTok("medidas ");#OtherTok("<-");#NormalTok(" pinguins ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(comprimento_bico_mm, profundidade_bico_mm,");],
[#NormalTok("         comprimento_nadadeira_mm, massa_g) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("na.omit");#NormalTok("()");],
[],
[#FunctionTok("cor");#NormalTok("(medidas) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("as.data.frame");#NormalTok("() ");#SpecialCharTok("|>");],
[#NormalTok("  tibble");#SpecialCharTok("::");#FunctionTok("rownames_to_column");#NormalTok("(");#StringTok("\"var1\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");#SpecialCharTok("-");#NormalTok("var1, ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"var2\"");#NormalTok(", ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"r\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(var1, var2, ");#AttributeTok("fill =");#NormalTok(" r)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_tile");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_text");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("label =");#NormalTok(" ");#FunctionTok("round");#NormalTok("(r, ");#DecValTok("2");#NormalTok(")), ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_gradient2");#NormalTok("(");#AttributeTok("low =");#NormalTok(" ocean[");#StringTok("\"CORAL\"");#NormalTok("], ");#AttributeTok("mid =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(", ");#AttributeTok("high =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("],");],
[#NormalTok("                       ");#AttributeTok("midpoint =");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#AttributeTok("limits =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#SpecialCharTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"r\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("axis.text.x =");#NormalTok(" ");#FunctionTok("element_text");#NormalTok("(");#AttributeTok("angle =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("1");#NormalTok("))");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-heatmap-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Mapa de calor das correlações entre as medidas morfométricas dos pinguins.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-heatmap>


== A evolução no tempo
<a-evolução-no-tempo>
Quando o eixo é o #strong[tempo] (ou qualquer sequência ordenada), o gráfico fala de #strong[tendência].

O #strong[gráfico de linhas] (segundo do menu da IDE) liga os pontos na ordem, revelando subidas e quedas. Aqui, a CPUE média de pescada-amarela mês a mês.

#Skylighting(([#NormalTok("cpue_mes ");#OtherTok("<-");#NormalTok(" captura_pescada_amarela ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(mes) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");#AttributeTok("cpue_media =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(cpue))");],
[],
[#FunctionTok("ggplot");#NormalTok("(cpue_mes, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" mes, ");#AttributeTok("y =");#NormalTok(" cpue_media, ");#AttributeTok("group =");#NormalTok(" ");#DecValTok("1");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_line");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"NAVY\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"CPUE média\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("axis.text.x =");#NormalTok(" ");#FunctionTok("element_text");#NormalTok("(");#AttributeTok("angle =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("1");#NormalTok("))");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-linhas-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico de linhas: CPUE média de pescada-amarela ao longo dos meses.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-linhas>


O #strong[gráfico de área] é uma linha com o "chão" preenchido --- útil para enfatizar volume acumulado ou magnitude ao longo do tempo, como a precipitação média mensal.

#Skylighting(([#NormalTok("chuva_mes ");#OtherTok("<-");#NormalTok(" captura_pescada_amarela ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(mes) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");#AttributeTok("prec_media =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(precipitacao))");],
[],
[#FunctionTok("ggplot");#NormalTok("(chuva_mes, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" mes, ");#AttributeTok("y =");#NormalTok(" prec_media, ");#AttributeTok("group =");#NormalTok(" ");#DecValTok("1");#NormalTok(")) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_area");#NormalTok("(");#AttributeTok("fill =");#NormalTok(" ocean[");#StringTok("\"SEAFOAM\"");#NormalTok("], ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.6");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_line");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("], ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("0.8");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Precipitação média (mm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("axis.text.x =");#NormalTok(" ");#FunctionTok("element_text");#NormalTok("(");#AttributeTok("angle =");#NormalTok(" ");#DecValTok("30");#NormalTok(", ");#AttributeTok("hjust =");#NormalTok(" ");#DecValTok("1");#NormalTok("))");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-area-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico de área: precipitação média por mês.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-area>


== A comparação entre categorias
<a-comparação-entre-categorias>
Quando a pergunta é "qual grupo tem mais?", o gráfico fala de #strong[magnitude por categoria].

O #strong[gráfico de barras] (terceiro do menu da IDE) é o cavalo de batalha: uma barra por categoria, altura proporcional ao valor. Use #NormalTok("geom_col()"); quando você já tem o valor calculado, e #NormalTok("geom_bar()"); quando quer que o R #strong[conte] as ocorrências.

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(captura_pescada_amarela, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" nome_aparelho_pesca,");],
[#NormalTok("                                    ");#AttributeTok("fill =");#NormalTok(" nome_aparelho_pesca)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_bar");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Nº de viagens\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-barras-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico de barras: número de viagens por aparelho de pesca.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-barras>


O #strong[gráfico de pizza] mostra #strong[composição] --- a fatia de cada categoria no todo. É, na verdade, um gráfico de barras "enrolado" num círculo (#NormalTok("coord_polar");). Funciona bem com #strong[poucas] categorias; com muitas, vira um disco confuso e as barras comunicam melhor.

#Skylighting(([#NormalTok("composicao ");#OtherTok("<-");#NormalTok(" captura_pescada_amarela ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("count");#NormalTok("(nome_aparelho_pesca) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("prop =");#NormalTok(" n ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("sum");#NormalTok("(n))");],
[],
[#FunctionTok("ggplot");#NormalTok("(composicao, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" prop, ");#AttributeTok("fill =");#NormalTok(" nome_aparelho_pesca)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_col");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#DecValTok("1");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("coord_polar");#NormalTok("(");#AttributeTok("theta =");#NormalTok(" ");#StringTok("\"y\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_text");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("label =");#NormalTok(" scales");#SpecialCharTok("::");#FunctionTok("percent");#NormalTok("(prop, ");#AttributeTok("accuracy =");#NormalTok(" ");#DecValTok("1");#NormalTok(")),");],
[#NormalTok("            ");#AttributeTok("position =");#NormalTok(" ");#FunctionTok("position_stack");#NormalTok("(");#AttributeTok("vjust =");#NormalTok(" ");#FloatTok("0.5");#NormalTok("), ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"Aparelho\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_void");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-pizza-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico de pizza: composição das viagens por aparelho de pesca.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-pizza>


Quando a comparação envolve #strong[médias com incerteza], o #strong[gráfico de barras de erro] (média ± erro padrão) é o mais honesto: ele mostra o valor central e o quanto ele pode oscilar.

#Skylighting(([#NormalTok("resumo ");#OtherTok("<-");#NormalTok(" biometria_caranguejos ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(Local) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");#AttributeTok("media =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(LC),");],
[#NormalTok("            ");#AttributeTok("ep =");#NormalTok(" ");#FunctionTok("sd");#NormalTok("(LC) ");#SpecialCharTok("/");#NormalTok(" ");#FunctionTok("sqrt");#NormalTok("(");#FunctionTok("n");#NormalTok("()))");],
[],
[#FunctionTok("ggplot");#NormalTok("(resumo, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" Local, ");#AttributeTok("y =");#NormalTok(" media, ");#AttributeTok("color =");#NormalTok(" Local)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("(");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_errorbar");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("ymin =");#NormalTok(" media ");#SpecialCharTok("-");#NormalTok(" ep, ");#AttributeTok("ymax =");#NormalTok(" media ");#SpecialCharTok("+");#NormalTok(" ep), ");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.15");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Largura média (mm)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-erro-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Médias da largura da carapaça por local, com barras de erro (± 1 erro padrão).
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-erro>


== O perfil multivariado
<o-perfil-multivariado>
Quando você quer comparar #strong[vários atributos de uma vez] entre poucos grupos, o #strong[gráfico de radar] (ou #emph[spider]) desenha um polígono por grupo sobre eixos que partem de um centro comum. É ótimo para "perfis" --- por exemplo, comparar as três espécies de pinguim em quatro medidas, padronizadas de 0 a 1 para caberem na mesma escala.

#Skylighting(([#NormalTok("reescala ");#OtherTok("<-");#NormalTok(" ");#ControlFlowTok("function");#NormalTok("(x) (x ");#SpecialCharTok("-");#NormalTok(" ");#FunctionTok("min");#NormalTok("(x)) ");#SpecialCharTok("/");#NormalTok(" (");#FunctionTok("max");#NormalTok("(x) ");#SpecialCharTok("-");#NormalTok(" ");#FunctionTok("min");#NormalTok("(x))");],
[],
[#NormalTok("perfil ");#OtherTok("<-");#NormalTok(" pinguins ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("na.omit");#NormalTok("() ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(especie) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");#FunctionTok("across");#NormalTok("(");#FunctionTok("c");#NormalTok("(comprimento_bico_mm, profundidade_bico_mm,");],
[#NormalTok("                     comprimento_nadadeira_mm, massa_g), mean)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#FunctionTok("across");#NormalTok("(");#SpecialCharTok("-");#NormalTok("especie, reescala)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("pivot_longer");#NormalTok("(");#SpecialCharTok("-");#NormalTok("especie, ");#AttributeTok("names_to =");#NormalTok(" ");#StringTok("\"eixo\"");#NormalTok(", ");#AttributeTok("values_to =");#NormalTok(" ");#StringTok("\"valor\"");#NormalTok(")");],
[],
[#FunctionTok("ggplot");#NormalTok("(perfil, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" eixo, ");#AttributeTok("y =");#NormalTok(" valor, ");#AttributeTok("group =");#NormalTok(" especie, ");#AttributeTok("color =");#NormalTok(" especie)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_polygon");#NormalTok("(");#AttributeTok("fill =");#NormalTok(" ");#ConstantTok("NA");#NormalTok(", ");#AttributeTok("linewidth =");#NormalTok(" ");#DecValTok("1");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_point");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("coord_polar");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"NAVY\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(", ");#StringTok("\"CORAL\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#ConstantTok("NULL");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"Espécie\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("axis.text.y =");#NormalTok(" ");#FunctionTok("element_blank");#NormalTok("())");],));
#figure([
#box(image("capitulos\\capitulo14/criacao_graficos_visualizacao_files/figure-typst/fig-radar-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Gráfico de radar: perfil morfométrico médio das três espécies de pinguim (medidas reescaladas de 0 a 1).
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-radar>


Um aviso de uso: o radar é sedutor, mas só funciona com #strong[poucos grupos e poucos eixos]\; além disso, depende da ordem dos eixos. Para muitas variáveis, prefira o mapa de calor ou um painel de boxplots.

== Escolhendo o gráfico certo
<escolhendo-o-gráfico-certo>
A #ref(<tbl-escolha>, supplement: [Tabela]) resume a galeria pela pergunta que cada gráfico responde.

#figure([
#table(
  columns: (40%, 25%, 35%),
  align: (left,left,left,),
  table.header([A sua pergunta], [Gráfico], [Camada principal (#NormalTok("ggplot2");)],),
  table.hline(),
  [Como uma variável se distribui?], [histograma, densidade], [#NormalTok("geom_histogram()");, #NormalTok("geom_density()");],
  [Como comparo distribuições?], [boxplot, violino], [#NormalTok("geom_boxplot()");, #NormalTok("geom_violin()");],
  [Duas variáveis andam juntas?], [dispersão], [#NormalTok("geom_point()"); + #NormalTok("geom_smooth()");],
  [Quais variáveis se correlacionam?], [mapa de calor], [#NormalTok("geom_tile()");],
  [Como evolui no tempo?], [linhas, área], [#NormalTok("geom_line()");, #NormalTok("geom_area()");],
  [Qual categoria tem mais?], [barras], [#NormalTok("geom_bar()");, #NormalTok("geom_col()");],
  [Qual a composição do todo?], [pizza], [#NormalTok("geom_col()"); + #NormalTok("coord_polar()");],
  [Médias com incerteza?], [barras de erro], [#NormalTok("geom_errorbar()");],
  [Perfil de poucos grupos em vários atributos?], [radar], [#NormalTok("geom_polygon()"); + #NormalTok("coord_polar()");],
)
], caption: figure.caption(
position: top, 
[
Da pergunta ao gráfico: um guia rápido da galeria.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-escolha>


#block[
#callout(
body: 
[
Visualizar é comunicar, e cada pergunta tem o seu gráfico. Para #strong[distribuição], histograma, densidade, boxplot e violino; para #strong[relação], dispersão e mapa de calor; para #strong[tempo], linhas e área; para #strong[comparar categorias], barras, pizza e barras de erro; para #strong[perfis multivariados], radar. Tudo na mesma gramática do #NormalTok("ggplot2"); --- dados, #NormalTok("aes()"); e camadas #NormalTok("geom_*"); empilhadas com #NormalTok("+"); ---, exatamente o código que o menu #emph[Visualizando Dados] da CatalyseR gera para você. Escolha pela mensagem, não pela aparência: o melhor gráfico é o que faz a informação saltar aos olhos.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Refaça o gráfico de barras usando #NormalTok("captura_petrechos");: número de registros por #NormalTok("Petrecho");. Depois transforme-o num gráfico de pizza. Qual comunica melhor com três categorias?
+ Faça um gráfico de linhas da CPUE média por mês, mas separando por #NormalTok("nome_aparelho_pesca"); (uma linha para cada). Use #NormalTok("color = nome_aparelho_pesca"); e remova o #NormalTok("group = 1");.
+ Monte um radar comparando as embarcações #NormalTok("B1"); a #NormalTok("B7"); em três métricas (CPUE média, precipitação média, dias ao mar médios). O que muda quando você reordena os eixos?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Criação de Mapas em R
<criação-de-mapas-em-r>
Ou: do dado ao território --- três mapas para ver melhor a pesca e a aquicultura

\
#block[
#callout(
body: 
[
Você abre o anuário da piscicultura e encontra uma tabela com a produção de cada estado --- vinte e sete linhas de números. Dá para ler, com paciência, que o Paraná lidera. Mas #emph[onde], no mapa do Brasil, está a força da aquicultura? A tabela não mostra que o Sul e o Norte puxam a produção enquanto boa parte do interior fica pálida. Um número vira território quando entra num #strong[mapa] --- e é aí que a pergunta "quem produz mais?" ganha, de relance, uma resposta geográfica.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Mapa é gráfico, só que com #strong[geografia] embaixo. Em vez de um eixo x e um eixo y, temos a forma real do território, e a posição e a cor de cada elemento contam uma história --- quanto se produziu num estado, onde uma rede foi lançada, qual a captura em cada estação.

== Por que mapas num livro de estatística?
<por-que-mapas-num-livro-de-estatística>
Um mapa #strong[não substitui] a análise estatística --- ele a prepara. Antes de comparar médias, ajustar uma regressão ou testar uma associação, vale saber #strong[onde] os dados foram coletados, se há #strong[concentração espacial], se existem #strong[vazios de amostragem] e se o #strong[ambiente] pode explicar parte da variação. É a mesma lógica da unidade "Antes da análise": olhar os dados antes de testá-los, só que agora no espaço. Um bom mapa ajuda a #strong[formular perguntas melhores].

Por isso o menu #strong[Mapas] da CatalyseR --- e este capítulo --- não vira um curso de geoprocessamento. Ficamos com #strong[três] tipos de mapa, e eles se organizam por #strong[propósito]:

#figure([
#table(
  columns: (24%, 26%, 50%),
  align: (left,left,left,),
  table.header([], [Mapa], [Pergunta que responde],),
  table.hline(),
  [#strong[Analisar quantidades]], [Coroplético], [Onde a variável agregada por área é maior ou menor?],
  [#strong[Analisar quantidades]], [Bolhas proporcionais], [Qual a magnitude (CPUE, biomassa) em cada local?],
  [#strong[Apoiar a amostragem]], [Pontos / estações], [Onde a coleta aconteceu? A cobertura é boa? Há lacunas?],
)
], caption: figure.caption(
position: top, 
[
Os três mapas da primeira edição e o que cada um responde.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-mapas>


Deixamos de fora, por ora, mapas de densidade, rasters ambientais e mapas interativos: úteis, mas fora do foco de um curso introdutório de estatística aplicada. A regra é simples --- #strong[mapa só entra se ajudar a ver melhor os dados, planejar melhor a coleta ou interpretar melhor uma pergunta].

== Dados espaciais: áreas e pontos
<dados-espaciais-áreas-e-pontos>
Há duas naturezas de dado espacial neste capítulo. A primeira é o dado #strong[agregado por área] --- a produção de um #emph[estado inteiro] ---, que pinta polígonos (o coroplético). A segunda é o dado de #strong[pontos] --- cada linha tem uma #strong[latitude] e uma #strong[longitude] ---, que marca lugares no mapa (estações e bolhas). Saber de qual tipo é o seu dado já decide qual mapa fazer.

== Mapa 1 --- Coroplético: a produção por estado
<mapa-1-coroplético-a-produção-por-estado>
=== Os dados: a aquicultura brasileira
<os-dados-a-aquicultura-brasileira>
Vamos trabalhar com o conjunto #NormalTok("aquicultura_br");, do pacote #NormalTok("EAPADados");. São dados públicos dos anuários da #strong[Revista PEIXE BR]: para cada estado e ano (2016 a 2023), a produção da piscicultura em toneladas e a posição no ranking nacional.

#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(aquicultura_br)");],));
#block[
#Skylighting(([#NormalTok("Rows: 216");],
[#NormalTok("Columns: 5");],
[#NormalTok("$ uf         <chr> \"PR\", \"SP\", \"MG\", \"RO\", \"SC\", \"MA\", \"MT\", \"MS\", \"BA\", \"PE\",…");],
[#NormalTok("$ estado     <chr> \"PARANÁ\", \"SÃO PAULO\", \"MINAS GERAIS\", \"RONDÔNIA\", \"SANTA C…");],
[#NormalTok("$ posicao    <int> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, …");],
[#NormalTok("$ producao_t <dbl> 213300, 82400, 61600, 56500, 56100, 49143, 44900, 34100, 34…");],
[#NormalTok("$ ano        <int> 2023, 2023, 2023, 2023, 2023, 2023, 2023, 2023, 2023, 2023,…");],));
]
]
A coluna que abre as portas do mapa é a #NormalTok("uf"); --- a #strong[sigla] do estado (PR, SP, PA…). Guarde essa ideia: para juntar dados a um mapa de áreas, precisamos de uma coluna que sirva de #strong[chave] entre a tabela e a geometria. A sigla é essa chave.

Antes de mapear, um gráfico de barras já responde à pergunta do começo --- quem lidera em 2023:

#Skylighting(([#NormalTok("aqui23 ");#OtherTok("<-");#NormalTok(" aquicultura_br ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(ano ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("2023");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(");#FunctionTok("desc");#NormalTok("(producao_t))");],
[],
[#NormalTok("aqui23 ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("slice_max");#NormalTok("(producao_t, ");#AttributeTok("n =");#NormalTok(" ");#DecValTok("10");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#FunctionTok("reorder");#NormalTok("(uf, producao_t), ");#AttributeTok("y =");#NormalTok(" producao_t)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_col");#NormalTok("(");#AttributeTok("fill =");#NormalTok(" ocean[");#StringTok("\"TEAL\"");#NormalTok("]) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("coord_flip");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Os dez maiores produtores (2023)\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Estado (UF)\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Produção (t)\"");#NormalTok(")");],));
#box(image("capitulos\\capitulo15/criacao_mapas_em_R_files/figure-typst/top10-1.svg"))

O gráfico ordena, mas não #strong[localiza]. Paraná, São Paulo, Minas, Rondônia --- onde eles estão? Para responder, precisamos da forma do Brasil.

=== Geometria, dados e junção
<geometria-dados-e-junção>
Todo coroplético nasce de três peças: uma #strong[geometria] (os contornos dos estados), uma #strong[tabela de dados] (a produção) e uma #strong[junção] que casa as duas por uma chave comum.

A geometria vem do pacote #strong[#NormalTok("geobr");], mantido pelo IPEA. Ele baixa os limites oficiais do IBGE --- sem você caçar #emph[shapefiles] na mão --- e entrega um objeto #strong[#NormalTok("sf");] (#emph[simple features]), que é um #NormalTok("data.frame"); com uma coluna especial de geometria. O objeto traz a coluna #NormalTok("abbrev_state"); com a sigla de cada estado: a chave da junção.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(geobr)");],
[#FunctionTok("library");#NormalTok("(sf)");],
[],
[#CommentTok("# Geometria dos 27 estados (na 1ª vez precisa de internet; year é obrigatório)");],
[#NormalTok("estados ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("read_state");#NormalTok("(");#AttributeTok("code_state =");#NormalTok(" ");#StringTok("\"all\"");#NormalTok(", ");#AttributeTok("year =");#NormalTok(" ");#DecValTok("2020");#NormalTok(", ");#AttributeTok("showProgress =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok(")");],
[],
[#CommentTok("# Junta a produção de 2023 pela sigla do estado");],
[#NormalTok("juntos ");#OtherTok("<-");#NormalTok(" estados ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("inner_join");#NormalTok("(");#FunctionTok("filter");#NormalTok("(aquicultura_br, ano ");#SpecialCharTok("==");#NormalTok(" ");#DecValTok("2023");#NormalTok("), ");#AttributeTok("by =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"abbrev_state\"");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#StringTok("\"uf\"");#NormalTok("))");],
[],
[#CommentTok("# Faixas à mão: a última (\"acima de 100.000\") isola o outlier Paraná");],
[#NormalTok("juntos");#SpecialCharTok("$");#NormalTok("categoria ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("cut");#NormalTok("(juntos");#SpecialCharTok("$");#NormalTok("producao_t,");],
[#NormalTok("                        ");#AttributeTok("breaks =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#DecValTok("0");#NormalTok(", ");#DecValTok("5000");#NormalTok(", ");#DecValTok("15000");#NormalTok(", ");#DecValTok("30000");#NormalTok(", ");#DecValTok("100000");#NormalTok(", ");#ConstantTok("Inf");#NormalTok("),");],
[#NormalTok("                        ");#AttributeTok("include.lowest =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(",");],
[#NormalTok("                        ");#AttributeTok("labels =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"até 5.000\"");#NormalTok(", ");#StringTok("\"5.001 – 15.000\"");#NormalTok(", ");#StringTok("\"15.001 – 30.000\"");#NormalTok(",");],
[#NormalTok("                                   ");#StringTok("\"30.001 – 100.000\"");#NormalTok(", ");#StringTok("\"acima de 100.000\"");#NormalTok("))");],
[],
[#FunctionTok("ggplot");#NormalTok("(juntos) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_sf");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("fill =");#NormalTok(" categoria), ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"white\"");#NormalTok(", ");#AttributeTok("linewidth =");#NormalTok(" ");#FloatTok("0.2");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_brewer");#NormalTok("(");#AttributeTok("palette =");#NormalTok(" ");#StringTok("\"GnBu\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Produção da aquicultura por estado — 2023\"");#NormalTok(", ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"Produção (t)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_void");#NormalTok("()");],));
]
#figure([
#box(image("capitulos\\capitulo15/../../images/mapa_aquicultura_2023.png", width: 78.0%))
], caption: figure.caption(
position: bottom, 
[
Coroplético da produção aquícola por estado em 2023, em faixas --- com o #strong[Paraná] isolado na faixa mais alta (acima de 100.000 t), o que espalha melhor os demais nas faixas inferiores. Gerado por #NormalTok("images/gerar_mapa_cap15.R");. Fonte: Revista PEIXE BR; malha IBGE via #NormalTok("geobr");.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-mapa-aqui>


Duas decisões dão o acabamento. A primeira é a #strong[classe]: o olho compara faixas melhor do que tons quase idênticos, e o Paraná, sendo um #strong[valor atípico], achataria uma escala contínua --- por isso reservamos uma faixa só para ele. A segunda são os #strong[enfeites que não são enfeites]: a #strong[barra de escala] e a #strong[rosa-dos-ventos] (do pacote #NormalTok("ggspatial");), que todo mapa científico pede.

== Mapa 2 --- Pontos e estações: onde a coleta aconteceu
<mapa-2-pontos-e-estações-onde-a-coleta-aconteceu>
Este é o mapa que #strong[apoia a amostragem]. Ele não fala de quanto, e sim de #strong[onde]: mostra cada estação de coleta no território, para você discutir cobertura espacial, lacunas de amostragem e se todos os ambientes foram contemplados --- a conversa do planejamento amostral, antes de qualquer teste.

Usamos o conjunto de exemplo #NormalTok("estacoes_ictiofauna"); (do #NormalTok("EAPADados");), com estações na costa norte do Pará. Cada linha tem #strong[latitude], #strong[longitude], o #strong[ambiente] e uma medida de captura:

#block[
#Skylighting(([#FunctionTok("glimpse");#NormalTok("(estacoes_ictiofauna)");],));
#block[
#Skylighting(([#NormalTok("Rows: 14");],
[#NormalTok("Columns: 9");],
[#NormalTok("$ id_estacao <chr> \"E01\", \"E02\", \"E03\", \"E04\", \"E05\", \"E06\", \"E07\", \"E08\", \"E0…");],
[#NormalTok("$ latitude   <dbl> -0.8290, -0.8800, -0.7800, -0.9500, -1.0536, -0.6160, -0.77…");],
[#NormalTok("$ longitude  <dbl> -46.6040, -46.6300, -46.6300, -46.6800, -46.7656, -47.3560,…");],
[#NormalTok("$ ano        <int> 2023, 2023, 2023, 2023, 2023, 2023, 2023, 2023, 2024, 2024,…");],
[#NormalTok("$ campanha   <fct> Seca, Seca, Seca, Seca, Seca, Seca, Seca, Seca, Chuvosa, Ch…");],
[#NormalTok("$ ambiente   <fct> Praia, Manguezal, Estuario, Manguezal, Estuario, Praia, Pla…");],
[#NormalTok("$ especie    <fct> Pescada-amarela, Bagre, Robalo, Bagre, Pescada-amarela, Rob…");],
[#NormalTok("$ cpue       <dbl> 12.4, 28.7, 19.1, 22.3, 15.8, 9.6, 33.5, 41.2, 18.9, 35.1, …");],
[#NormalTok("$ abundancia <int> 31, 64, 40, 51, 37, 22, 70, 88, 44, 79, 52, 49, 95, 110");],));
]
]
Agora os pontos viram um objeto #NormalTok("sf"); (com #NormalTok("st_as_sf()");, informando as colunas de coordenada e o sistema de referência, #strong[CRS 4326] = graus de lat/lon), plotados sobre a base dos estados, recortada na região:

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(geobr); ");#FunctionTok("library");#NormalTok("(sf); ");#FunctionTok("library");#NormalTok("(ggplot2)");],
[],
[#CommentTok("# Pontos como sf e base recortada na área de estudo");],
[#NormalTok("pts ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_as_sf");#NormalTok("(estacoes_ictiofauna, ");#AttributeTok("coords =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(");#StringTok("\"longitude\"");#NormalTok(", ");#StringTok("\"latitude\"");#NormalTok("), ");#AttributeTok("crs =");#NormalTok(" ");#DecValTok("4326");#NormalTok(")");],
[#NormalTok("estados ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_transform");#NormalTok("(");#FunctionTok("read_state");#NormalTok("(");#AttributeTok("code_state =");#NormalTok(" ");#StringTok("\"all\"");#NormalTok(", ");#AttributeTok("year =");#NormalTok(" ");#DecValTok("2020");#NormalTok(", ");#AttributeTok("showProgress =");#NormalTok(" ");#ConstantTok("FALSE");#NormalTok("), ");#DecValTok("4326");#NormalTok(")");],
[#NormalTok("bb ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("st_bbox");#NormalTok("(pts)");],
[],
[#FunctionTok("ggplot");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_sf");#NormalTok("(");#AttributeTok("data =");#NormalTok(" estados, ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"#EAF0F2\"");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"grey75\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_sf");#NormalTok("(");#AttributeTok("data =");#NormalTok(" pts, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("color =");#NormalTok(" ambiente, ");#AttributeTok("shape =");#NormalTok(" ambiente), ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ggrepel");#SpecialCharTok("::");#FunctionTok("geom_text_repel");#NormalTok("(");#AttributeTok("data =");#NormalTok(" pts, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("label =");#NormalTok(" id_estacao, ");#AttributeTok("geometry =");#NormalTok(" geometry),");],
[#NormalTok("                           ");#AttributeTok("stat =");#NormalTok(" ");#StringTok("\"sf_coordinates\"");#NormalTok(", ");#AttributeTok("size =");#NormalTok(" ");#DecValTok("3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("coord_sf");#NormalTok("(");#AttributeTok("xlim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(bb[");#StringTok("\"xmin\"");#NormalTok("], bb[");#StringTok("\"xmax\"");#NormalTok("]), ");#AttributeTok("ylim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(bb[");#StringTok("\"ymin\"");#NormalTok("], bb[");#StringTok("\"ymax\"");#NormalTok("])) ");#SpecialCharTok("+");],
[#NormalTok("  ggspatial");#SpecialCharTok("::");#FunctionTok("annotation_scale");#NormalTok("(");#AttributeTok("location =");#NormalTok(" ");#StringTok("\"br\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ggspatial");#SpecialCharTok("::");#FunctionTok("annotation_north_arrow");#NormalTok("(");#AttributeTok("location =");#NormalTok(" ");#StringTok("\"tr\"");#NormalTok(",");],
[#NormalTok("                                    ");#AttributeTok("style =");#NormalTok(" ggspatial");#SpecialCharTok("::");#FunctionTok("north_arrow_fancy_orienteering");#NormalTok("()) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Estações de coleta de ictiofauna — costa do Pará\"");#NormalTok(",");],
[#NormalTok("       ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"Ambiente\"");#NormalTok(", ");#AttributeTok("shape =");#NormalTok(" ");#StringTok("\"Ambiente\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Longitude\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Latitude\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_bw");#NormalTok("()");],));
]
#figure([
#box(image("capitulos\\capitulo15/../../images/mapa_estacoes_pontos.png", width: 88.0%))
], caption: figure.caption(
position: bottom, 
[
Mapa de estações de coleta na costa do Pará, com rótulos (#NormalTok("ggrepel");), grade de coordenadas, escala e Norte, e um #strong[mapa de localização] (inset) marcando a área de estudo no Brasil --- o formato esperado numa figura de "Material e Métodos" de TCC ou artigo. Dados de exemplo; gerado por #NormalTok("images/gerar_mapa_cap15.R");.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-estacoes>


Note os detalhes que transformam um punhado de pontos numa #strong[figura de publicação]: #strong[rótulos] que não se sobrepõem (o #NormalTok("ggrepel"); afasta o texto e puxa uma linha), a #strong[grade de coordenadas] em graus, a #strong[cor e a forma] por ambiente (para o mapa continuar legível impresso em preto e branco) e o #strong[inset] de localização. A CatalyseR liga tudo isso com caixas de seleção no menu #strong[Mapas › Pontos / Estações].

== Mapa 3 --- Bolhas proporcionais: a magnitude em cada local
<mapa-3-bolhas-proporcionais-a-magnitude-em-cada-local>
O mapa de pontos diz #emph[onde]\; o de #strong[bolhas] diz #emph[quanto]. É a extensão natural: cada estação vira um círculo cujo #strong[tamanho] representa uma variável numérica --- CPUE, biomassa, abundância. De relance, o leitor vê onde os valores são maiores e se a magnitude se concentra em alguma região.

#block[
#Skylighting(([#FunctionTok("ggplot");#NormalTok("() ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_sf");#NormalTok("(");#AttributeTok("data =");#NormalTok(" estados, ");#AttributeTok("fill =");#NormalTok(" ");#StringTok("\"#EAF0F2\"");#NormalTok(", ");#AttributeTok("color =");#NormalTok(" ");#StringTok("\"grey75\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_sf");#NormalTok("(");#AttributeTok("data =");#NormalTok(" pts, ");#FunctionTok("aes");#NormalTok("(");#AttributeTok("size =");#NormalTok(" cpue, ");#AttributeTok("color =");#NormalTok(" ambiente), ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_size_area");#NormalTok("(");#AttributeTok("max_size =");#NormalTok(" ");#DecValTok("11");#NormalTok(", ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"CPUE\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("coord_sf");#NormalTok("(");#AttributeTok("xlim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(bb[");#StringTok("\"xmin\"");#NormalTok("], bb[");#StringTok("\"xmax\"");#NormalTok("]), ");#AttributeTok("ylim =");#NormalTok(" ");#FunctionTok("c");#NormalTok("(bb[");#StringTok("\"ymin\"");#NormalTok("], bb[");#StringTok("\"ymax\"");#NormalTok("])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_color_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean), ");#AttributeTok("name =");#NormalTok(" ");#StringTok("\"Ambiente\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"CPUE por estação — costa do Pará\"");#NormalTok(", ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Longitude\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Latitude\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("()");],));
]
#figure([
#box(image("capitulos\\capitulo15/../../images/mapa_estacoes_bolhas.png", width: 88.0%))
], caption: figure.caption(
position: bottom, 
[
Bolhas proporcionais: o tamanho de cada círculo é a CPUE da estação; a cor indica o ambiente. As maiores capturas aparecem na plataforma. Dados de exemplo; gerado por #NormalTok("images/gerar_mapa_cap15.R");.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-bolhas>


O detalhe técnico que importa é o #NormalTok("scale_size_area()");: ele faz a #strong[área] da bolha --- não o raio --- ser proporcional ao valor, que é como o olho compara tamanhos com honestidade. Limite o tamanho máximo e, se houver bolhas demais se sobrepondo, o caminho é agregar por local ou voltar ao mapa de pontos.

#block[
#callout(
body: 
[
Os três mapas vivem no menu #strong[Mapas] da CatalyseR --- #emph[Coroplético], #emph[Pontos / Estações] e #emph[Bolhas Proporcionais] ---, feitos apontando e clicando: você carrega o conjunto, escolhe as colunas (a sigla do estado, ou a latitude/longitude, ou a variável da bolha), e a IDE desenha o mapa #strong[e exporta o script R] que o reproduz. O mapa que você vê é o mesmo que o código escreve.

]
, 
title: 
[
Do mouse ao código
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Mapa é gráfico com geografia embaixo, e num livro de estatística ele serve para #strong[ver melhor os dados antes de analisá-los]. Ficamos com três, por propósito. Para #strong[analisar quantidades]: o #strong[coroplético], que pinta áreas conforme um valor (geometria do #NormalTok("geobr"); + dados + #strong[junção] por uma chave --- a sigla #NormalTok("uf"); ↔ #NormalTok("abbrev_state");), com #strong[classes] que isolam #emph[outliers]\; e as #strong[bolhas proporcionais], cujo tamanho (via #NormalTok("scale_size_area()");) mede a magnitude em cada ponto. Para #strong[apoiar a amostragem]: o mapa de #strong[pontos e estações], que mostra onde a coleta aconteceu, com rótulos, grade, escala, Norte e inset --- pronto para um TCC ou artigo. Tudo estático, reprodutível e exportável, espelhando o menu #strong[Mapas] da CatalyseR.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Refaça o coroplético para #strong[2016] e compare com 2023: quais estados mudaram de faixa? (Dica: troque o #NormalTok("filter(ano == 2023)");.)
+ No mapa de #strong[estações], colora os pontos por #NormalTok("campanha"); em vez de #NormalTok("ambiente");. A cobertura muda entre a seca e a chuvosa?
+ No mapa de #strong[bolhas], troque #NormalTok("cpue"); por #NormalTok("abundancia"); no #NormalTok("aes(size = ...)");. A leitura da magnitude muda? E se você #strong[facetar] por #NormalTok("ano"); (#NormalTok("facet_wrap(~ ano)");)?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Relatórios e Comunicação de Dados com Quarto
<relatórios-e-comunicação-de-dados-com-quarto>
Ou: o último passo do mouse ao código --- a análise vira um relatório pronto

\
#block[
#callout(
body: 
[
A análise está pronta na tela: o teste deu significativo, o gráfico ficou bom, o número está ali. Aí vem a parte que ninguém ensina --- #strong[transformar isso num relatório] que outra pessoa entenda. E começa o sofrimento: copiar o #emph[p]-valor na mão (e errar uma casa decimal), colar o gráfico que descola na próxima edição, reescrever a mesma frase de conclusão pela milésima vez. Há um jeito melhor: deixar o #strong[relatório nascer da própria análise], com exatamente o que aquela análise precisa mostrar --- nem mais, nem menos.

]
, 
title: 
[
Já passou por isso?
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Este é o último capítulo, e fecha o ciclo do livro: a estatística que começou no #strong[mouse] (na IDE CatalyseR) e passou pelo #strong[código] (no R) termina aqui, num #strong[relatório reproduzível]. A ferramenta é o #strong[Quarto]: um documento único que junta #strong[texto], #strong[código] e #strong[resultados] e os transforma em HTML, PDF ou Word --- sempre atualizados, porque os números e gráficos são gerados na hora, a partir dos dados, e não copiados à mão.

== O relatório certo para cada análise
<o-relatório-certo-para-cada-análise>
Aqui está a ideia central deste capítulo, e o princípio que guia a CatalyseR: #strong[cada análise pede uma saída específica]. Um teste #emph[t] não se comunica com as mesmas peças de uma regressão. Comunicar bem é entregar #strong[exatamente os resultados que aquela análise exige] --- e a IDE sabe disso: quando você termina uma análise e pede o relatório, ela gera um #NormalTok(".docx"); #strong[sob medida] para aquele método.

E o que cada análise exige se resume, quase sempre, a #strong[três peças]:

+ #strong[O relato] --- uma frase científica em português que conta o resultado (a estatística do teste, os graus de liberdade, o #emph[p]-valor, o intervalo de confiança e o tamanho do efeito), pronta para entrar num artigo ou relatório.
+ #strong[A tabela estruturada] --- os números organizados, no padrão visual do livro (tema #emph[Ocean Gradient], cabeçalho navy).
+ #strong[A figura] --- o gráfico que torna o resultado visível.

A CatalyseR produz essas três peças automaticamente, usando as #strong[funções canônicas] do #NormalTok("EAPADados"); --- as mesmas que você pode chamar no R. Vamos vê-las em ação.

== Anatomia de um relatório de análise
<anatomia-de-um-relatório-de-análise>
Retomemos o experimento da #emph[Artemia] (Unidade IV): duas rações comparadas por um teste #emph[t]. O #strong[relato] sai pronto, em uma frase, da função #NormalTok("relatar_teste_t_ind()");:

#quote(block: true)[
Foi conduzido um teste #emph[t] de Student para duas amostras independentes para variâncias iguais para comparar a variável a taxa de crescimento (mg/dia) entre os grupos definidos por o tipo de ração (A vs B). A média no grupo A foi de 4,09 e a média no grupo B foi de 3,47 (IC 95% da diferença \[0,15; 1,08\]). Os resultados indicaram uma diferença estatisticamente significativa entre as médias dos grupos, #emph[t]\(12,0) = 2,856, p = 0,014, sendo a média amostral do grupo A superior à média do grupo B. O tamanho do efeito, estimado pelo #emph[d] de Cohen, foi de 1,53, correspondendo a um efeito grande.
]

A #strong[tabela estruturada] vem de #NormalTok("mostrar_teste_t_ind()");, formatada no tema Ocean por #NormalTok("flextable_ocean()"); e citável por número (#ref(<tbl-relatorio>, supplement: [Tabela])):

#Skylighting(([#FunctionTok("mostrar_teste_t_ind");#NormalTok("(taxa_crescimento_mg_dia ");#SpecialCharTok("~");#NormalTok(" racao,");],
[#NormalTok("                    ");#AttributeTok("data =");#NormalTok(" artemia, ");#AttributeTok("equal_var =");#NormalTok(" ");#ConstantTok("TRUE");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("flextable_ocean");#NormalTok("()");],));
#figure([
#box(image("capitulos\\capitulo16/relatorios_comunicacao_dados_usando_quarto_files/figure-typst/tbl-relatorio-1.png"))

], caption: figure.caption(
position: top, 
[
Saída estruturada do teste t --- a tabela que a CatalyseR insere no relatório.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-relatorio>


E a #strong[figura] --- o boxplot que mostra a diferença:

#Skylighting(([#FunctionTok("ggplot");#NormalTok("(artemia, ");#FunctionTok("aes");#NormalTok("(racao, taxa_crescimento_mg_dia, ");#AttributeTok("fill =");#NormalTok(" racao)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("geom_boxplot");#NormalTok("(");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.85");#NormalTok(", ");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.3");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("scale_fill_manual");#NormalTok("(");#AttributeTok("values =");#NormalTok(" ");#FunctionTok("unname");#NormalTok("(ocean[");#FunctionTok("c");#NormalTok("(");#StringTok("\"TEAL\"");#NormalTok(", ");#StringTok("\"AMBER\"");#NormalTok(")])) ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Ração\"");#NormalTok(", ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Taxa de crescimento (mg/dia)\"");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#FunctionTok("theme");#NormalTok("(");#AttributeTok("legend.position =");#NormalTok(" ");#StringTok("\"none\"");#NormalTok(")");],));
#figure([
#box(image("capitulos\\capitulo16/relatorios_comunicacao_dados_usando_quarto_files/figure-typst/fig-relatorio-1.svg"))
], caption: figure.caption(
position: bottom, 
[
A figura que acompanha o relato e a tabela: taxa de crescimento por ração.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-relatorio>


Repare no ponto-chave: #strong[você não digitou nenhum número]. O #emph[p]-valor da frase, os valores da tabela e a altura das caixas no gráfico vêm todos do mesmo objeto, calculado a partir dos dados. Mude os dados, re-renderize, e o relatório inteiro se atualiza sozinho. É isso que significa um relatório #strong[reproduzível] --- e é exatamente o que a CatalyseR empacota para você.

== Do mouse ao código: o Projeto R que a CatalyseR exporta
<do-mouse-ao-código-o-projeto-r-que-a-catalyser-exporta>
Quando você conclui uma análise na IDE e clica em #strong[Exportar Projeto Consolidado], ela não entrega só um arquivo: entrega um #strong[Projeto R] (#NormalTok(".zip");) organizado, pronto para abrir no RStudio e renderizar. Lá dentro estão:

- os #strong[dados] já tratados (em #NormalTok(".rda"););
- os #strong[scripts] R numerados que reproduzem a análise;
- um #strong[#NormalTok("relatorio.qmd");] --- o documento Quarto com o texto, o código e as chamadas às funções canônicas (#NormalTok("relatar_*");, #NormalTok("mostrar_*");, #NormalTok("flextable_ocean"););
- um #strong[#NormalTok("custom-reference.docx");] --- o modelo de formatação para a saída em Word.

Ou seja: a IDE faz a análise no mouse e te entrega o #strong[código que a reproduz] e o #strong[relatório que a comunica]. Você sai com tudo na mão, podendo ajustar o texto, reexecutar e gerar a versão final.

== O motor: Quarto → Word com um modelo ABNT
<o-motor-quarto-word-com-um-modelo-abnt>
O coração da exportação é simples. O cabeçalho (YAML) do #NormalTok("relatorio.qmd"); declara o formato Word e aponta para o modelo de estilo:

#Skylighting(([#PreprocessorTok("---");],
[#FunctionTok("title");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"Relatório de Análise — Comparação de Rações\"");],
[#FunctionTok("format");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("docx");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("reference-doc");#KeywordTok(":");#AttributeTok(" custom-reference.docx");#CommentTok("   # estilos: TNR 12, justificado, A4 ABNT");],
[#AttributeTok("    ");#FunctionTok("toc");#KeywordTok(":");#AttributeTok(" ");#CharTok("true");#CommentTok("                              # sumário");],
[#AttributeTok("    ");#FunctionTok("number-sections");#KeywordTok(":");#AttributeTok(" ");#CharTok("true");#CommentTok("                  # títulos numerados");],
[#FunctionTok("lang");#KeywordTok(":");#AttributeTok(" pt-BR");],
[#PreprocessorTok("---");],));
O #NormalTok("custom-reference.docx"); é um documento Word "vazio" que carrega a identidade visual: #strong[Times New Roman 12], parágrafos #strong[justificados], página #strong[A4 com margens ABNT], #strong[sumário], #strong[títulos numerados] e #strong[número de página]. O Quarto aplica esses estilos ao gerar o #NormalTok(".docx");. A renderização é um comando só:

#Skylighting(([#ExtensionTok("quarto");#NormalTok(" render relatorio.qmd ");#AttributeTok("--to");#NormalTok(" docx");],));
Por baixo dos panos, a IDE monta num diretório temporário o #NormalTok("relatorio.qmd"); + o #NormalTok("custom-reference.docx"); + os dados (#NormalTok(".rda");) + os scripts, substitui as variáveis (qual análise, quais dados, quais rótulos) e roda esse #NormalTok("quarto render");. O resultado é um relatório Word com cara de publicação --- o relato, a tabela Ocean e a figura, na ordem certa, com a formatação certa.

#block[
#callout(
body: 
[
Nunca digite um resultado à mão. Todo número que aparece no texto deve vir de uma chamada de código (#NormalTok("r relatar_teste_t_ind(...)");), e toda tabela e figura devem ser geradas no próprio documento. Assim, o relatório nunca "mente" --- ele é, por construção, fiel aos dados.

]
, 
title: 
[
A regra de ouro do relatório reproduzível
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Um relatório para cada análise
<um-relatório-para-cada-análise>
A versão 1 do ecossistema cobre as análises que você já domina, e para cada uma há um conjunto mínimo de saídas --- o que a #ref(<tbl-saidas>, supplement: [Tabela]) resume. É esse mapeamento que a CatalyseR usa para montar o relatório certo conforme a análise escolhida.

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Análise], [Relato (#NormalTok("relatar_*");)], [Tabela (#NormalTok("mostrar_*");)], [Figura típica],),
  table.hline(),
  [Estatística descritiva], [resumo das medidas], [medidas de centro e dispersão], [histograma / boxplot],
  [Teste #emph[t] (1 amostra, independentes, pareadas)], [frase com #emph[t], gl, #emph[p], IC e #emph[d] de Cohen], [médias, diferença, IC, efeito], [boxplot por grupo],
  [ANOVA], [frase com #emph[F], gl, #emph[p] e pós-teste], [quadro da ANOVA + Tukey], [médias com erro],
  [Regressão linear simples], [frase com coeficientes, #emph[R²] e #emph[p]], [coeficientes e ajuste], [reta com IC],
  [Qui-quadrado], [frase de (in)dependência], [tabela de contingência], [barras por categoria],
)
], caption: figure.caption(
position: top, 
[
As saídas mínimas de cada análise --- o que entra no relatório que a CatalyseR gera.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabela", 
)
<tbl-saidas>


A lógica é sempre a mesma: a análise calcula (#NormalTok("calcular_*");), o relatório mostra (#NormalTok("mostrar_*");) e relata (#NormalTok("relatar_*");), e o Quarto empacota. Trocar de análise é trocar de trio de funções --- o motor de exportação é o mesmo.

#block[
#callout(
body: 
[
Comunicar é o último passo do #emph[mouse ao código]. Com o #strong[Quarto], o relatório nasce da própria análise: texto, código e resultados num só documento, exportável para HTML, PDF ou #strong[Word]. O princípio que guia a CatalyseR é entregar, para #strong[cada análise], exatamente as saídas que ela exige --- o #strong[relato] (#NormalTok("relatar_*");), a #strong[tabela] (#NormalTok("mostrar_*"); + #NormalTok("flextable_ocean");) e a #strong[figura] ---, sem digitar um número sequer. A IDE empacota tudo num #strong[Projeto R] (#NormalTok(".zip");) com o #NormalTok("relatorio.qmd"); e o #NormalTok("custom-reference.docx");, e um #NormalTok("quarto render --to docx"); produz o relatório final no padrão ABNT. Da coleta ao relatório, um fluxo só, reprodutível de ponta a ponta.

]
, 
title: 
[
Resumo do capítulo
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
+ Crie um #NormalTok(".qmd"); com #NormalTok("format: html");, escreva um parágrafo e insira um valor calculado com #NormalTok("r mean(artemia$taxa_crescimento_mg_dia)");. Renderize e confirme que o número aparece no texto.
+ Refaça o relatório do teste #emph[t] da #emph[Artemia] trocando #NormalTok("equal_var = TRUE"); por #NormalTok("FALSE"); (Welch). O relato e a tabela mudam sozinhos?
+ Gere o mesmo documento em três formatos (#NormalTok("html");, #NormalTok("pdf");, #NormalTok("docx");) trocando só o #NormalTok("format:"); do YAML. Qual exige o #NormalTok("custom-reference.docx");?

]
, 
title: 
[
Para praticar
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
none
, 
body_background_color: 
white
)
]
= Considerações Finais
<considerações-finais>
Este livro apresentou conceitos fundamentais de estatística aplicada à pesca e aquicultura, com ênfase em métodos descritivos e probabilísticos.

== Aplicações práticas
<aplicações-práticas>
- Planejamento de experimentos em viveiros
- Avaliação estatística de crescimento de peixes
- Análise de captura por unidade de esforço (CPUE)

== Próximos passos
<próximos-passos>
Nos capítulos seguintes, serão incluídas análises inferenciais, regressões e modelagens preditivas voltadas para dados ecológicos e produtivos da aquicultura.

#horizontalrule

Agradecemos por acompanhar esta jornada científica!

#set bibliography(style: "apa.csl")

#bibliography(("references.bib"))

