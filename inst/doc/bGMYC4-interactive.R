## ----include = FALSE----------------------------------------------------------
# EN: Disable execution for CRAN checks to prevent timeouts on interactive MCMC.
# RU: Отключено выполнение для проверки CRAN, чтобы избежать таймаутов.
# Для локального запуска: измените eval = FALSE на eval = TRUE или запускайте блоки вручную.
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7, fig.height = 5,
  warning = FALSE, message = FALSE,
  eval = FALSE
)

## ----setup--------------------------------------------------------------------
# compiler::enableJIT(3) # JIT acceleration / Ускорение JIT
# library(ape)
# library(bGMYC4)
# library(treeio)
# library(ggtree)
# library(dplyr)
# library(plotly)
# library(htmlwidgets)
# library(mcmcse)
# 
# # EN: Safe numeric scalar input / Безопасный ввод скалярных значений
# input_scalar <- function(label, default_val) {
#   if (!interactive()) return(default_val)
#   val <- readline(sprintf("  %s (default / по умолчанию: %s): ", label, default_val))
#   if (nchar(trimws(val)) == 0) return(default_val)
#   num <- suppressWarnings(as.numeric(val))
#   if (is.na(num)) return(default_val)
#   return(num)
# }
# 
# # EN: Safe numeric vector input / Безопасный ввод векторов
# input_vector <- function(label, default_vec) {
#   if (!interactive()) return(default_vec)
#   val <- readline(sprintf("  %s (comma-separated, default / через запятую, по умолчанию: %s): ",
#                           label, paste(default_vec, collapse = ", ")))
#   if (nchar(trimws(val)) == 0) return(default_vec)
#   nums <- suppressWarnings(as.numeric(unlist(strsplit(val, "[,;\\s]+"))))
#   nums <- nums[!is.na(nums)]
#   if (length(nums) != length(default_vec)) return(default_vec)
#   return(nums)
# }

## ----data---------------------------------------------------------------------
# consensus_path <- if (interactive()) readline("📥 Path to consensus tree / Путь к консенсусному дереву (.tree): ") else "dummy.tree"
# posterior_path <- if (interactive()) readline("📥 Path to posterior trees / Путь к набору деревьев (.trees): ") else "dummy.trees"
# 
# tree_beast <- treeio::read.beast(consensus_path)
# tree_consensus <- tree_beast@phylo
# all_trees <- read.nexus(posterior_path)
# class(all_trees) <- "multiPhylo"
# 
# # EN: Analysis Mode Selection / Выбор режима анализа
# mode_str <- if (interactive()) readline("Mode 1 (Single) or 2 (Multi)? / Режим 1 или 2? [2]: ") else "2"
# analysis_mode <- ifelse(nchar(trimws(mode_str)) == 0, 2, as.integer(mode_str))
# 
# # EN: Tree sampling with burnin / Выборка деревьев с учетом burnin
# if (analysis_mode == 2) {
#   n_total <- length(all_trees)
#   burnin_idx <- floor(n_total * 0.10) # 10% burnin
#   n_sample <- input_scalar("Number of trees to sample / Кол-во деревьев", 10)
#   set.seed(42)
#   trees_sample <- all_trees[sample((burnin_idx + 1):n_total, n_sample)]
#   class(trees_sample) <- "multiPhylo"
# } else {
#   trees_sample <- NULL
# }
# 
# # EN: Outgroup removal via regex patterns / Удаление аутгрупп по паттернам
# if (interactive() && tolower(readline("Drop outgroups? / Удалять аутгруппы? (y/n): ")) == "y") {
#   og_str <- readline("Enter patterns (comma-separated) / Введите паттерны: ")
#   og_patterns <- trimws(unlist(strsplit(og_str, "[,;]+")))
#   matching_tips <- unique(unlist(lapply(og_patterns, function(p) {
#     pattern <- paste0("(^|[^A-Za-z0-9])", p, "($|[^A-Za-z0-9])")
#     tree_consensus$tip.label[grepl(pattern, tree_consensus$tip.label, ignore.case = TRUE, perl = TRUE)]
#   })))
# 
#   if (length(matching_tips) > 0) {
#     tree_consensus <- drop.tip(tree_consensus, matching_tips)
#     if (analysis_mode == 2) {
#       trees_sample <- lapply(trees_sample, drop.tip, tip = matching_tips)
#       class(trees_sample) <- "multiPhylo"
#     }
#     tree_beast <- treeio::drop.tip(tree_beast, matching_tips)
#   }
# }
# 
# tree_consensus <- fix_ultrametric(tree_consensus)
# ntips <- length(tree_consensus$tip.label)

## ----diagnostics--------------------------------------------------------------
# params <- list(
#   mcmc = 10000, burnin = 1000, thinning = 10,
#   py1 = 0, py2 = 1.5, pc1 = 0, pc2 = 2,
#   t1 = 2, t2 = min(35, ntips - 1),
#   scale = c(20, 10, 5), start = c(1, 1, floor(ntips/3))
# )
# 
# # EN: Diagnostic tuning loop / Цикл диагностики и настройки
# repeat {
#   res_single <- bgmyc.singlephy(
#     phylo = tree_consensus, mcmc = params$mcmc, burnin = params$burnin,
#     thinning = params$thinning, py1 = params$py1, py2 = params$py2,
#     pc1 = params$pc1, pc2 = params$pc2, t1 = params$t1, t2 = params$t2,
#     scale = params$scale, start = params$start
#   )
# 
#   # EN: Convergence checks / Проверка сходимости
#   ar <- res_single$accept
#   cat(sprintf("Acceptance rates: py=%.3f | pc=%.3f | th=%.3f\n", ar[1], ar[2], ar[3]))
#   if (requireNamespace("mcmcse", quietly = TRUE)) {
#     ess_vals <- sapply(1:4, function(col) round(mcmcse::ess(res_single$par[, col])))
#     cat(sprintf("ESS: py=%d | pc=%d | th=%d | logL=%d [Target > 200]\n",
#                 ess_vals[1], ess_vals[2], ess_vals[3], ess_vals[4]))
#   }
# 
#   plot(res_single)
# 
#   if (!interactive() || tolower(readline("Accept parameters? / Принять параметры? (y/n): ")) != "n") break
# 
#   # EN: Update parameters / Обновление параметров
#   params$mcmc <- input_scalar("mcmc", params$mcmc)
#   params$burnin <- input_scalar("burnin", params$burnin)
#   params$thinning <- input_scalar("thinning", params$thinning)
#   params$scale <- input_vector("scale", params$scale)
#   params$start <- input_vector("start", params$start)
# }

## ----multi--------------------------------------------------------------------
# if (analysis_mode == 2) {
#   # EN: bgmyc.multiphylo() uses a parallel PSOCK cluster and returns a
#   #     "multibgmyc" object directly. cores = 1 (default) runs sequentially.
#   #     options(mc.cores = ...) has NO effect here.
#   # RU: bgmyc.multiphylo() использует PSOCK-кластер и сам возвращает объект
#   #     класса "multibgmyc". cores = 1 (по умолчанию) — последовательно.
#   #     options(mc.cores = ...) здесь НЕ действует.
#   # CRAN-safe: at most 2 workers. Locally you may raise it, e.g. cores = 6.
#   final_res <- bgmyc.multiphylo(
#     multiphylo = trees_sample,
#     mcmc = params$mcmc, burnin = params$burnin, thinning = params$thinning,
#     py1 = params$py1, py2 = params$py2, pc1 = params$pc1, pc2 = params$pc2,
#     t1 = params$t1, t2 = params$t2, scale = params$scale, start = params$start,
#     cores = 2, seed = 42
#   )
# 
#   # EN: Per-tree diagnostics. R-hat is NOT valid across different trees:
#   #     each posterior tree defines its own conditional posterior.
#   # RU: Диагностика по каждому дереву. R̂ между деревьями невалиден:
#   #     каждое дерево задаёт свой условный апостериор.
#   acc <- t(vapply(final_res, function(r) as.numeric(r$accept)[1:3], numeric(3)))
#   colnames(acc) <- c("py", "pc", "th")
#   cat("Acceptance rates (median across trees): ",
#       paste(sprintf("%s=%.3f", colnames(acc), apply(acc, 2, median)), collapse = " | "),
#       "\n", sep = "")
# 
#   if (requireNamespace("mcmcse", quietly = TRUE)) {
#     ess_th <- vapply(final_res, function(r) {
#       e <- tryCatch(as.numeric(mcmcse::ess(r$par[, 3])), error = function(e) NA_real_)
#       if (length(e) != 1L || !is.finite(e)) NA_real_ else e
#     }, numeric(1))
#     if (any(is.finite(ess_th)))
#       cat(sprintf("ESS(threshold): min=%d | median=%d | max=%d [target > 200]\n",
#                   round(min(ess_th, na.rm = TRUE)),
#                   round(median(ess_th, na.rm = TRUE)),
#                   round(max(ess_th, na.rm = TRUE))))
#   }
#   cat("Note: for a genuine R-hat, run several independent chains on ONE tree\n",
#       "      with bgmyc.chains() and summarise with bgmyc.convergence().\n", sep = "")
# 
# } else {
#   final_res <- list(res_single)
#   class(final_res) <- "multibgmyc"
# }

## ----plotly_viz---------------------------------------------------------------
# probmat <- spec.probmat(final_res)
# 
# # EN: Synchronize tip order between tree and matrix / Синхронизация порядка таксонов
# p_tree <- suppressWarnings(ggtree(tree_beast, layout = "rectangular"))
# tips_data <- p_tree$data %>% filter(isTip) %>% arrange(y)
# tip_order <- tips_data$label
# probmat <- probmat[tip_order, tip_order]
# 
# # EN: Extract posterior probabilities for branches / Извлечение posterior для ветвей
# post_col <- intersect(c("posterior", "prob", "Posterior"), colnames(p_tree$data))[1]
# node_posterior <- p_tree$data[[post_col]]
# names(node_posterior) <- p_tree$data$node
# 
# # EN: Custom color gradient function / Функция градиента цвета
# get_pp_color <- function(pp) {
#   if(is.na(pp)) return("#CCCCCC")
#   pp <- max(0, min(1, pp))
#   colors <- list(c(0.0, 1.0, 0.0, 0.0), c(0.25, 1.0, 0.5, 0.0),
#                  c(0.5, 1.0, 1.0, 0.0), c(0.75, 0.5, 1.0, 0.0), c(1.0, 0.0, 0.7, 0.0))
#   for(i in 1:(length(colors)-1)) {
#     if(pp >= colors[[i]][1] && pp <= colors[[i+1]][1]) {
#       t <- (pp - colors[[i]][1]) / (colors[[i+1]][1] - colors[[i]][1])
#       r <- colors[[i]][2] + t * (colors[[i+1]][2] - colors[[i]][2])
#       g <- colors[[i]][3] + t * (colors[[i+1]][3] - colors[[i]][3])
#       b <- colors[[i]][4] + t * (colors[[i+1]][4] - colors[[i]][4])
#       return(sprintf("#%02X%02X%02X", round(r*255), round(g*255), round(b*255)))
#     }
#   }
#   return("#CCCCCC")
# }
# 
# # EN: Build Plotly Tree / Построение дерева в Plotly
# edges <- p_tree$data %>% filter(!is.na(parent))
# fig_tree <- plot_ly()
# for(i in 1:nrow(edges)) {
#   child <- edges[i, ]
#   parent <- p_tree$data %>% filter(node == child$parent)
#   branch_color <- get_pp_color(node_posterior[as.character(child$node)])
#   fig_tree <- fig_tree %>% add_segments(
#     x = parent$x, xend = child$x, y = child$y, yend = child$y,
#     line = list(color = branch_color, width = 5), showlegend = FALSE)
#   fig_tree <- fig_tree %>% add_segments(
#     x = parent$x, xend = parent$x, y = parent$y, yend = child$y,
#     line = list(color = branch_color, width = 5), showlegend = FALSE)
# }
# 
# # EN: Build Plotly Heatmap / Построение тепловой карты
# fig_heat <- plot_ly(
#   z = probmat, x = 1:nrow(probmat), y = 1:ncol(probmat), type = "heatmap",
#   colorscale = list(list(0.0, "#F7FCF5"), list(0.5, "#41AB5D"), list(1.0, "#00441B")),
#   zmin = 0, zmax = 1, showscale = TRUE
# )
# 
# # EN: Combine 1:1 / Объединение 1:1
# fig_combined <- subplot(fig_tree, fig_heat, nrows = 1, widths = c(0.5, 0.5), shareY = TRUE) %>%
#   layout(yaxis = list(autorange = "reversed", showticklabels = FALSE),
#          xaxis = list(showticklabels = FALSE),
#          xaxis2 = list(showticklabels = FALSE),
#          yaxis2 = list(autorange = "reversed", showticklabels = FALSE))
# 
# htmlwidgets::saveWidget(fig_combined, "bGMYC_interactive_heatmap.html", selfcontained = TRUE)

## ----export-------------------------------------------------------------------
# # EN: Export clusters at different thresholds / Экспорт кластеров на разных порогах
# thresholds <- c(0.05, 0.01)
# for (p in thresholds) {
#   # EN: single-linkage warning is expected; see README "Choosing ppcutoff".
#   # RU: предупреждение single linkage ожидаемо; см. README "Choosing ppcutoff".
#   out <- suppressWarnings(bgmyc.point(probmat, ppcutoff = p))
#   df <- data.frame(
#     Sequence = unlist(out),
#     MOTU_bGMYC = rep(seq_along(out), lengths(out)),
#     stringsAsFactors = FALSE
#   )
#   fname <- sprintf("Delimitation_bGMYC_%.3f.csv", p)
#   utils::write.table(df, file = fname,
#                      row.names = FALSE, sep = ";", dec = ".", quote = FALSE)
#   cat(sprintf("✅ ppcutoff=%.3f → %d clusters → %s\n", p, length(out), fname))
# }
# 
# # EN: Export full probability matrix / Экспорт полной матрицы вероятностей
# spec_out <- bgmyc.spec(final_res)
# utils::write.csv(spec_out$specprobs, "bGMYC_full_probs.csv", row.names = FALSE)
# cat("✅ bGMYC_full_probs.csv saved\n")

