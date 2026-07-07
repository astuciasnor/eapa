# Prompt para gerar a imagem de abertura (Capítulo 11 — Regressão Linear Simples)

Figura: infográfico de abertura que **explica visualmente a regressão linear
simples** usando os caranguejos de Bragança (`EAPADados::biometria_caranguejos`).
Ideia central: um gráfico de dispersão **comprimento × largura da carapaça**, com
a **reta de mínimos quadrados**, alguns **resíduos** destacados e a **equação** do
modelo.

> Dica geral: modelos de imagem ainda erram texto. Mantenha **poucos rótulos** e,
> se algum sair torto, gere de novo ou deixe para rotular na diagramação do livro
> (a legenda da figura já carrega a explicação). Peça **proporção retrato 4:5** e
> alta resolução (≥ 1500 px). Números do modelo real (para manter coerência):
> equação *CC = 28,44 + 0,421 · LC*; *R²* = 0,12; *n* = 993. (R² baixo é
> proposital: a relação é real, mas fraca — bom gancho para discutir o R².)

---

## Prompt principal — infográfico vetorial (recomendado), em português

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à pesca e à
aquicultura. Tema: a IDEIA da regressão linear simples, ilustrada com caranguejos
do litoral amazônico (caranguejo-uçá, de Bragança, Pará).

Composição central — um gráfico de dispersão grande e elegante:
- Eixo X horizontal rotulado "Largura da carapaça — LC (mm)"; eixo Y vertical
  rotulado "Comprimento da carapaça — CC (mm)". Linhas de grade finas e discretas.
- Uma nuvem de pontos subindo levemente da esquerda inferior para a direita
  superior, porém BEM ESPALHADA (relação positiva mas fraca). Alguns pontos podem
  ser pequenos ícones estilizados de caranguejo visto de cima; o restante,
  círculos em verde-petróleo (#2E7D8F).
- Uma RETA reta atravessando a nuvem na diagonal ascendente, em coral (#E76F51),
  grossa — a "reta de mínimos quadrados".
- Em três ou quatro pontos, pequenos segmentos verticais tracejados ligando o
  ponto à reta, representando os RESÍDUOS (a distância de cada ponto à reta).
- Um balão/etiqueta limpo com a equação "CC = β₀ + β₁ · LC" e, abaixo,
  "R² = 0,12".

Elementos de contexto (discretos, nos cantos):
- No canto superior, um caranguejo-uçá estilizado visto de cima (carapaça e duas
  pinças), simples e elegante, em azul-marinho (#0F3B5F) com toques de âmbar.
- Sugerir as dimensões medidas na carapaça: uma seta horizontal (largura, LC) e
  uma vertical (comprimento, CC) sobre o caranguejo do canto.

Texto curto e nítido, em PORTUGUÊS, apenas estes rótulos:
título "Regressão linear simples"; "Comprimento da carapaça — CC (mm)";
"Largura da carapaça — LC (mm)"; "reta de mínimos quadrados"; "resíduo = y − ŷ";
"CC = β₀ + β₁ · LC"; "R² = 0,12". Nada de texto além desses.

Estilo: design editorial científico, linhas finas, ícones simples, sombras
suaves, paleta Ocean Gradient (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51),
tipografia sem serifa limpa. Sem fotorrealismo, sem excesso de detalhes.
Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído,
caranguejos irreais, aparência 3D pesada.
```

---

## Variante em inglês (costuma renderizar o texto com mais precisão)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on statistics applied to fisheries and aquaculture. Theme: the
IDEA of simple linear regression, illustrated with Amazonian mangrove crabs
(caranguejo-uçá, from Bragança, Pará, Brazil).

Central composition — one large, elegant scatter plot:
- Horizontal X axis labeled "Largura da carapaça — LC (mm)"; vertical Y axis
  labeled "Comprimento da carapaça — CC (mm)". Thin, discreet gridlines.
- A cloud of points rising gently from lower-left to upper-right but CLEARLY
  SCATTERED (positive yet weak relationship). Some points can be small stylized
  top-view crab icons; the rest teal dots (#2E7D8F).
- A straight LINE crossing the cloud on the ascending diagonal, in coral
  (#E76F51), thick — the "least-squares line".
- At three or four points, small dashed vertical segments connecting the point to
  the line, representing the RESIDUALS.
- A clean callout with the equation "CC = β₀ + β₁ · LC" and below it "R² = 0,12".

Context elements (subtle, in corners):
- Top corner: a stylized top-view mangrove crab (carapace + two claws), simple
  and elegant, navy (#0F3B5F) with amber touches; show a horizontal arrow (width,
  LC) and a vertical arrow (length, CC) over the carapace.

Short, crisp on-image text, in PORTUGUESE, ONLY these labels:
title "Regressão linear simples"; "Comprimento da carapaça — CC (mm)";
"Largura da carapaça — LC (mm)"; "reta de mínimos quadrados"; "resíduo = y − ŷ";
"CC = β₀ + β₁ · LC"; "R² = 0,12".

Style: scientific editorial design, thin lines, simple icons, soft shadows,
Ocean Gradient palette (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51), clean
sans-serif type. No photorealism, no clutter. Portrait 4:5, high resolution.
Avoid: watermark, gibberish text, logos, busy background, unrealistic crabs,
heavy 3D look.
```

---

## Variante B — ilustração editorial (mais "cena", menos diagrama)

```
Ilustração editorial limpa e didática: numa praia de manguezal de Bragança,
caranguejos-uçá de tamanhos variados enfileirados do menor ao maior, sugerindo
que carapaças mais largas tendem a ser mais compridas. Sobreposta à cena, de
forma leve, uma reta diagonal ascendente em coral atravessa os caranguejos como
uma "reta de tendência", com a etiqueta discreta "CC = β₀ + β₁ · LC". Atmosfera
clara, paleta em azuis-petróleo e âmbar (Ocean Gradient: #0F3B5F, #2E7D8F,
#62B6B7, #E89B3C, #E76F51). Composição equilibrada, foco na ideia de relação
crescente. Pouco ou nenhum texto. Proporção retrato 4:5, alta resolução. Sem
marca d'água.
```

---

## Onde salvar e como inserir no livro (Quarto)

1. Salve a imagem gerada em `eapa/images/` com o nome:
   `regressao_caranguejo_cc_lc.png` (PNG, fundo branco, ≥ 1500 px de largura).

2. No capítulo `capitulos/capitulo11/regressao_linear_simples_multipla.qmd`,
   logo após o gancho de abertura (callout "Já passou por isso?"), insira:

```markdown
![A regressão linear simples em uma imagem: cada caranguejo é um ponto no gráfico
de comprimento contra largura da carapaça; a reta de mínimos quadrados resume a
relação, e os segmentos tracejados marcam os resíduos (a distância de cada ponto
à reta). Fonte: elaborado pelo autor a partir do conjunto `biometria_caranguejos`
(EAPADados).](../../images/regressao_caranguejo_cc_lc.png){#fig-regressao-caranguejo width=90%}
```

3. Para referenciar no texto: "...como sintetiza a @fig-regressao-caranguejo."

> Observação: o caminho `../../images/` vale porque o capítulo está em
> `capitulos/capitulo11/` e a pasta de imagens é `eapa/images/`.
