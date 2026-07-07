# Prompt para gerar a imagem de abertura (Capítulo 05 — Preparando os dados)

Figura: infográfico do fluxo de **arrumação de dados** — de uma planilha **larga e
bagunçada** para dados **tidy (arrumados)**, passando pelos três movimentos:
**empilhar** (largo → longo), **alargar** (uma métrica por coluna) e **separar**
(quebrar uma coluna composta). Contexto: desembarque pesqueiro amazônico.

> Dica geral: modelos de imagem ainda erram texto. Mantenha **poucos rótulos** e,
> se algum sair torto, gere de novo ou deixe para rotular na diagramação do livro
> (a legenda da figura já carrega a explicação). Peça **proporção retrato 4:5** e
> alta resolução (≥ 1500 px).

---

## Prompt principal — infográfico vetorial (recomendado), em português

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à pesca. Tema: a
transformação de uma planilha de dados bagunçada em dados organizados ("tidy"),
no contexto de desembarque pesqueiro.

Composição da esquerda para a direita, com grandes setas de fluxo:
- À ESQUERDA, uma planilha "larga" e confusa: muitas colunas estreitas com
  rótulos repetidos tipo "2021 - Captura", "2021 - Receita", "2022 - Captura"...
  Aparência apertada, tom de alerta em coral/âmbar (#E76F51, #E89B3C), passando a
  ideia de bagunça.
- AO CENTRO, três engrenagens/setas empilhadas, cada uma um movimento, com um
  ícone simples: EMPILHAR (colunas viram linhas — setas descendo), ALARGAR (uma
  métrica por coluna), SEPARAR (uma célula "PARGO-2023" partindo-se em pedaços).
- À DIREITA, uma tabela limpa e organizada ("tidy") em tons de verde-petróleo e
  verde-água (#2E7D8F, #62B6B7): poucas colunas claras — porto, espécie, ano,
  captura, receita —, uma linha por observação, com um pequeno visto/check verde.
- Elementos de pesca discretos ao fundo: um pequeno porto com barcos, silhuetas
  de peixes estilizados, um caixote de pescado.

Texto curto e nítido, em PORTUGUÊS, apenas estes rótulos:
título "Do caos ao tidy"; "Largo (bagunçado)"; "empilhar"; "alargar"; "separar";
"Tidy (arrumado)". Nada de texto além desses.

Estilo: design editorial científico, linhas finas, ícones simples, sombras
suaves, paleta Ocean Gradient (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51),
tipografia sem serifa limpa. Sem fotorrealismo, sem excesso de detalhes.
Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído,
aparência 3D pesada.
```

---

## Variante em inglês (costuma renderizar o texto com mais precisão)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on fisheries statistics. Theme: transforming a messy spreadsheet
into tidy data, in a fishery landings context.

Left-to-right composition with large flow arrows:
- LEFT: a messy "wide" spreadsheet with many narrow columns and repeated headers
  like "2021 - Catch", "2021 - Revenue", "2022 - Catch"... cramped, warning tone
  in coral/amber (#E76F51, #E89B3C), conveying disorder.
- CENTER: three stacked gears/arrows, each a move with a simple icon: STACK
  (columns become rows), WIDEN (one metric per column), SPLIT (a cell
  "PARGO-2023" breaking into pieces).
- RIGHT: a clean tidy table in teal and seafoam (#2E7D8F, #62B6B7): few clear
  columns — port, species, year, catch, revenue —, one row per observation, a
  small green check.
- Subtle fishery elements in the back: a small port with boats, stylized fish
  silhouettes, a fish crate.

Short, crisp on-image text, in PORTUGUESE, ONLY these labels:
title "Do caos ao tidy"; "Largo (bagunçado)"; "empilhar"; "alargar"; "separar";
"Tidy (arrumado)".

Style: scientific editorial design, thin lines, simple icons, soft shadows,
Ocean Gradient palette (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51), clean
sans-serif type. No photorealism, no clutter. Portrait 4:5, high resolution.
Avoid: watermark, gibberish text, logos, busy background, heavy 3D look.
```

---

## Onde salvar e como inserir no livro (Quarto)

1. Salve a imagem gerada em `eapa/images/` com o nome:
   `preparo_dados_tidy.png` (PNG, fundo branco, ≥ 1500 px de largura).

2. No capítulo `capitulos/capitulo05/preparando_os_dados.qmd`, logo após o
   parágrafo de abertura, o marcador da figura já está no lugar:

```markdown
![Da planilha larga e bagunçada aos dados *tidy*: empilhar tira o ano/medida do
cabeçalho, alargar deixa cada medida em sua coluna, e separar quebra uma coluna
composta. Fonte: elaborado pelo autor.](../../images/preparo_dados_tidy.png){#fig-preparo width=85%}
```

3. Para referenciar no texto: "...como resume a @fig-preparo."

> Observação: o caminho `../../images/` vale porque o capítulo está em
> `capitulos/capitulo05/` e a pasta de imagens é `eapa/images/`.
