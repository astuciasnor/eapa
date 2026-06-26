# Prompt para gerar a imagem de abertura (Capítulo 11 — Regressão Linear Simples)

Figura: infográfico de abertura que **explica visualmente a regressão linear
simples** usando os pinguins do Arquipélago Palmer (dados `palmerpenguins` /
`EAPADados::pinguins`). Ideia central: um gráfico de dispersão **massa corporal ×
comprimento da nadadeira**, com a **reta de mínimos quadrados**, alguns
**resíduos** destacados e a **equação** do modelo. Referência visual de estilo e
contexto: <https://allisonhorst.github.io/palmerpenguins/index.html>.

> Dica geral: modelos de imagem ainda erram texto. Mantenha **poucos rótulos** e,
> se algum sair torto, gere de novo ou deixe para rotular na diagramação do livro
> (a legenda da figura já carrega a explicação). Peça **proporção retrato 4:5** e
> alta resolução (≥ 1500 px). Números do modelo real (para manter coerência):
> equação *massa = −5780,8 + 49,69 · nadadeira*; *R²* = 0,76; *n* = 342.

---

## Prompt principal — infográfico vetorial (recomendado), em português

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à pesca e à
aquicultura. Tema: a IDEIA da regressão linear simples, ilustrada com pinguins do
Arquipélago Palmer (Antártica).

Composição central — um gráfico de dispersão grande e elegante:
- Eixo X horizontal rotulado "Comprimento da nadadeira (mm)"; eixo Y vertical
  rotulado "Massa corporal (g)". Linhas de grade finas e discretas.
- Uma nuvem de pontos subindo da esquerda inferior para a direita superior
  (relação positiva e forte). Alguns pontos podem ser pequenos ícones
  estilizados de pinguim de corpo inteiro; o restante, círculos coloridos.
- Três cores de pontos para três espécies: Adélie verde-petróleo (#2E7D8F),
  Gentoo âmbar (#E89B3C), Chinstrap azul-marinho (#0F3B5F).
- Uma RETA reta atravessando a nuvem na diagonal ascendente, em coral (#E76F51),
  grossa — a "reta de mínimos quadrados".
- Em três ou quatro pontos, pequenos segmentos verticais tracejados ligando o
  ponto à reta, representando os RESÍDUOS (a distância de cada ponto à reta).
- Um balão/etiqueta limpo com a equação "massa = β₀ + β₁ · nadadeira" e, abaixo,
  "R² = 0,76".

Elementos de contexto (discretos, nos cantos):
- No canto superior, um trio de pinguins estilizados (Adélie, Gentoo, Chinstrap)
  de frente, fofos e simples.
- Um pequeno selo/mapa minimalista do "Arquipélago Palmer · Antártica" com três
  ilhotas, como inset no canto.

Texto curto e nítido, em PORTUGUÊS, apenas estes rótulos:
título "Regressão linear simples"; "Massa corporal (g)"; "Comprimento da
nadadeira (mm)"; "reta de mínimos quadrados"; "resíduo = y − ŷ";
"massa = β₀ + β₁ · nadadeira"; "R² = 0,76". Nada de texto além desses.

Estilo: design editorial científico, linhas finas, ícones simples, sombras
suaves, paleta Ocean Gradient (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51),
tipografia sem serifa limpa. Sem fotorrealismo, sem excesso de detalhes.
Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído,
pinguins irreais, aparência 3D pesada, gelo/neve em excesso que tire o foco do
gráfico.
```

---

## Variante em inglês (costuma renderizar o texto com mais precisão)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on statistics applied to fisheries and aquaculture. Theme: the
IDEA of simple linear regression, illustrated with Palmer Archipelago penguins
(Antarctica).

Central composition — one large, elegant scatter plot:
- Horizontal X axis labeled "Comprimento da nadadeira (mm)"; vertical Y axis
  labeled "Massa corporal (g)". Thin, discreet gridlines.
- A cloud of points rising from lower-left to upper-right (strong positive
  relationship). Some points can be small stylized full-body penguin icons; the
  rest colored dots.
- Three point colors for three species: Adélie teal (#2E7D8F), Gentoo amber
  (#E89B3C), Chinstrap navy (#0F3B5F).
- A straight LINE crossing the cloud on the ascending diagonal, in coral
  (#E76F51), thick — the "least-squares line".
- At three or four points, small dashed vertical segments connecting the point to
  the line, representing the RESIDUALS.
- A clean callout with the equation "massa = β₀ + β₁ · nadadeira" and below it
  "R² = 0,76".

Context elements (subtle, in corners):
- Top corner: a trio of stylized penguins (Adélie, Gentoo, Chinstrap), cute and
  simple, facing front.
- A small minimalist map inset "Arquipélago Palmer · Antártica" with three islets.

Short, crisp on-image text, in PORTUGUESE, ONLY these labels:
title "Regressão linear simples"; "Massa corporal (g)"; "Comprimento da
nadadeira (mm)"; "reta de mínimos quadrados"; "resíduo = y − ŷ";
"massa = β₀ + β₁ · nadadeira"; "R² = 0,76".

Style: scientific editorial design, thin lines, simple icons, soft shadows,
Ocean Gradient palette (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51), clean
sans-serif type. No photorealism, no clutter. Portrait 4:5, high resolution.
Avoid: watermark, gibberish text, logos, busy background, unrealistic penguins,
heavy 3D look, excessive ice/snow that distracts from the chart.
```

---

## Variante B — ilustração editorial (mais "cena", menos diagrama)

```
Ilustração editorial limpa e didática: numa praia rochosa do Arquipélago Palmer,
pinguins de três espécies (Adélie, Gentoo, Chinstrap) enfileirados do menor ao
maior, sugerindo que nadadeiras mais compridas acompanham corpos mais pesados.
Sobreposta à cena, de forma leve, uma reta diagonal ascendente em coral
atravessa os pinguins como uma "reta de tendência", com a etiqueta discreta
"massa = β₀ + β₁ · nadadeira". Atmosfera clara, paleta em azuis-petróleo e âmbar
(Ocean Gradient: #0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51). Composição
equilibrada, foco na ideia de relação crescente. Pouco ou nenhum texto.
Proporção retrato 4:5, alta resolução. Sem marca d'água.
```

---

## Onde salvar e como inserir no livro (Quarto)

1. Salve a imagem gerada em `eapa/images/` com o nome:
   `regressao_pinguins_massa_nadadeira.png` (PNG, fundo branco, ≥ 1500 px de
   largura).

2. No capítulo `capitulos/capitulo11/regressao_linear_simples_multipla.qmd`,
   logo após o gancho de abertura (callout "Já passou por isso?"), insira:

```markdown
![A regressão linear simples em uma imagem: cada pinguim do Arquipélago Palmer é
um ponto no gráfico de massa corporal contra comprimento da nadadeira; a reta de
mínimos quadrados resume a relação, e os segmentos tracejados marcam os resíduos
(a distância de cada ponto à reta). Fonte: elaborado a partir de
@palmerpenguins.](../../images/regressao_pinguins_massa_nadadeira.png){#fig-regressao-pinguins width=90%}
```

3. Para referenciar no texto: "...como sintetiza a @fig-regressao-pinguins."

> Observação: o caminho `../../images/` vale porque o capítulo está em
> `capitulos/capitulo11/` e a pasta de imagens é `eapa/images/`. Se ainda não
> houver a entrada `@palmerpenguins` nas referências, troque a fonte por
> "elaborado pelo autor a partir do conjunto `pinguins` (EAPADados)".
