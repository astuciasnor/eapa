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

Recomenda-se ler este livro com o R aberto. Cada capítulo foi escrito para ser acompanhado na prática: instale o pacote de dados, execute os exemplos, gere os gráficos e produza os relatórios. É percorrendo esse caminho, e repetindo-o, que a fluência se constrói.

#heading(level: 2, numbering: none)[Agradecimentos]
<agradecimentos>
Aos estudantes de graduação e pós-graduação da Universidade Federal do Pará, cuja participação ao longo dos anos foi essencial para o aprimoramento do ensino de estatística aqui consolidado.

Aos professores da UFPA que gentilmente cederam scripts e resultados de pesquisa, adaptados e incluídos como dados de apoio nas análises deste material.

À Editora da UFPA, pela valiosa ajuda na editoração deste livro e pelo cuidado com a qualidade do acabamento.

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

= Tratamento Básico de Dados e Visualização Gráfica Inicial
<tratamento-básico-de-dados-e-visualização-gráfica-inicial>
= Analise Exploratória de Dados e Estatística Descritiva
<analise-exploratória-de-dados-e-estatística-descritiva>
= Planejamento Amostral e Delineamentos de Experimentos
<planejamento-amostral-e-delineamentos-de-experimentos>
Trazer aquele textto sobre captur de camarões de dados do eduardo e que mostrei na sala de aula para a turma de 2022. \
Projeto camarão

Incluir sobre o capítulo de pseudo-réplica e aplicar a uma pesquisa de conjutno de dados.

Incluir DIC. DBC , DQL e DF

= Testes estatísticos paramétricos para uma e duas amostras
<testes-estatísticos-paramétricos-para-uma-e-duas-amostras>
= Testes Não-paramétricos para uma e duas amostras
<testes-não-paramétricos-para-uma-e-duas-amostras>
= Regressão Linear Simples e Múultipla.
<regressão-linear-simples-e-múultipla.>
= Análise de Correlação e Associação entre váriáveis
<análise-de-correlação-e-associação-entre-váriáveis>
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
#box(image("capitulos\\capitulo11/../../images/experimento_anova_bagres.png", width: 85.0%))
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
#Skylighting(([#NormalTok("'data.frame':   19 obs. of  2 variables:");],
[#NormalTok(" $ racao : Factor w/ 4 levels \"A\",\"B\",\"C\",\"D\": 1 1 1 1 1 2 2 2 2 2 ...");],
[#NormalTok(" $ peso_g: num  86 83 91 84 87 88 87 94 86 89 ...");],));
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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-medias-1.png"))

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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/fig-boxplot-1.svg"))
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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-anova-1.png"))

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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-pressupostos-1.png"))

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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/fig-qq-1.svg"))
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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/fig-residuos-1.svg"))
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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/tbl-tukey-1.png"))

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
#box(image("capitulos\\capitulo11/anova_estudos_observacionais_experimentais_files/figure-typst/fig-tukey-1.svg"))
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
<para-praticar-2>
+ Refaça a ANOVA #strong[sem] a ração C e veja se as conclusões sobre A, B e D mudam.
+ O que aconteceria com a tabela de pressupostos se um valor de C fosse, digamos, 130 g (um #emph[outlier])? Teste e interprete.
+ Troque o pós-teste de Tukey por comparações com #NormalTok("pairwise.t.test()"); e compare as conclusões.

#heading(level: 2, numbering: none)[Referências]
<referências>
#block[
] <refs>
= Análise de Covariância e Comparação de Inclinações
<análise-de-covariância-e-comparação-de-inclinações>
= Análise de Regressão Não Linear
<análise-de-regressão-não-linear>
= Análise de Séries Temporais
<análise-de-séries-temporais>
e Médias Móveis

= Análise Multivariada de Dados
<análise-multivariada-de-dados>
= Criação de Mapas em R
<criação-de-mapas-em-r>
= Análise de Experimentos por Metodologia Superfície de Respostas
<análise-de-experimentos-por-metodologia-superfície-de-respostas>
= Relatórios e Comunicação de Dados usando Quarto
<relatórios-e-comunicação-de-dados-usando-quarto>
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

#heading(level: 1, numbering: none)[References]
<references>
#block[
] <refs>



#set bibliography(style: "abnt.csl")

#bibliography(("references.bib"))

