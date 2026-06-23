# Prompt — Figura "As três ferramentas" (Capítulo 2)

Figura de abertura das ferramentas do ecossistema: **R**, **RStudio** e **Quarto**.
Gerar em IA de imagem (ex.: ChatGPT/DALL·E, Midjourney). Estilo padrão do livro EAPA:
flat design, paleta Ocean Gradient, fundo claro, sem texto extra além dos rótulos pedidos.

> **Atenção aos logos.** IAs de imagem costumam **distorcer logos de marca**. Para fidelidade
> perfeita, o ideal é baixar os logos oficiais (R: r-project.org; RStudio/Posit: posit.co;
> Quarto: quarto.org) e montar a figura como SVG. O prompt abaixo serve para uma versão
> ilustrativa/aproximada.

---

## Prompt (PT)

Crie uma ilustração horizontal, estilo flat design minimalista, mostrando **três cartões
lado a lado** que representam três ferramentas de análise de dados. Fundo branco/cinza
muito claro. Cada cartão é um retângulo de cantos arredondados, com uma fina borda, na
paleta de cores "Ocean Gradient": azul-marinho #0F3B5F, azul-petróleo #2E7D8F,
verde-água #62B6B7, âmbar #E89B3C.

- **Cartão 1 — R:** um ícone que evoque o logotipo da linguagem R (a letra "R" estilizada
  sobre uma elipse/anel cinza-azulado). Abaixo, o rótulo grande "R" e, em letra menor,
  o texto "a linguagem".
- **Cartão 2 — RStudio:** um ícone que evoque o logotipo do RStudio (um painel/janela com
  um pequeno "R" dentro de um círculo azul). Abaixo, o rótulo "RStudio" e, menor,
  "o ateliê (onde você trabalha)".
- **Cartão 3 — Quarto:** um ícone que evoque o logotipo do Quarto (um círculo azul com a
  letra "q" ou um "balão"/blockquote estilizado). Abaixo, o rótulo "Quarto" e, menor,
  "o editor de relatórios".

Composição limpa, muito espaço em branco, sombras suaves ou nenhuma, sem gradientes
chamativos, sem texto solto além dos rótulos indicados. Proporção 16:6 (bem horizontal),
alta resolução, tipografia sem serifa.

---

## Prompt (EN)

A minimalist flat-design horizontal illustration showing **three cards side by side**,
each representing a data-analysis tool. Very light gray/white background. Each card is a
rounded-corner rectangle with a thin border, using the "Ocean Gradient" palette: navy
#0F3B5F, teal #2E7D8F, seafoam #62B6B7, amber #E89B3C.

- **Card 1 — R:** an icon evoking the R language logo (a stylized letter "R" over a
  blue-gray oval ring). Below it, a large label "R" and, smaller, "a linguagem".
- **Card 2 — RStudio:** an icon evoking the RStudio logo (a window/panel with a small "R"
  inside a blue circle). Below it, "RStudio" and, smaller, "o ateliê (onde você trabalha)".
- **Card 3 — Quarto:** an icon evoking the Quarto logo (a blue circle with a "q" or a
  stylized blockquote bracket). Below it, "Quarto" and, smaller, "o editor de relatórios".

Clean composition, generous whitespace, soft or no shadows, no flashy gradients, no stray
text beyond the indicated labels. Aspect ratio 16:6 (wide), high resolution, sans-serif type.

---

## Inserir no capítulo 2 (Quarto)

Salve a imagem em `eapa/images/ferramentas_r_rstudio_quarto.png` e insira:

```markdown
![As três ferramentas de base do ecossistema: o R (a linguagem que faz as contas),
o RStudio (o ambiente onde você escreve e roda o código) e o Quarto (que transforma a
análise em relatório). Você instala as três uma única vez.](../../images/ferramentas_r_rstudio_quarto.png){#fig-ferramentas width=95%}
```

E, no texto, referencie com `@fig-ferramentas`.
