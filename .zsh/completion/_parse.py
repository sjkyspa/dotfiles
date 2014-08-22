#compdef parse.py
#
# this is zsh completion function file.
# generated by genzshcomp(ver: 0.5.1)
#

typeset -A opt_args
local context state line

_arguments -s -S \
  "-h[show this help message and exit]:" \
  "--help[show this help message and exit]:" \
  "-d[Set the directory to look for data in (default \"results\").]::DIR:_files" \
  "--dir[Set the directory to look for data in (default \"results\").]::DIR:_files" \
  "--print-all-data[Pretty print all data to stdout]" \
  "-p[choose what to plot (default \"m\")]::PLOTS:_files" \
  "--plots[choose what to plot (default \"m\")]::PLOTS:_files" \
  "-v[Choose values to print]::PRINT_DATA:_files:" \
  "--print-data[Choose values to print]::PRINT_DATA:_files" \
  "-l[Add additional labels to line, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::LABEL:_files" \
  "--label[Add additional labels to line, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::LABEL:_files" \
  "-s[Split into different plots for different values of these keys, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::SPLIT:_files" \
  "--split[Split into different plots for different values of these keys, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::SPLIT:_files" \
  "-t[Split into different data sets in a scatter plot for different values of these keys, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::SCATTER_SPLIT:_files" \
  "--scatter-split[Split into different data sets in a scatter plot for different values of these keys, for keys begining with dash specify them as: \`-s=-dt\` to avoid issues with \`-\` being read as a new argument.]::SCATTER_SPLIT:_files" \
  "--skip-failed[Skip runs which failed (dir contains file named failed)]" \
  "-f[Filter runs based on parameters. Input should be a python pair like ('-tol', 1e-3) where the first entry is the dictionary key to check and the second entry is the value it should take. Note the quotes around the key.]::FILTER:_files" \
  "--filter[Filter runs based on parameters. Input should be a python pair like ('-tol', 1e-3) where the first entry is the dictionary key to check and the second entry is the value it should take. Note the quotes around the key.]::FILTER:_files" \
  "--not-filter[Oposite of -filter: only use runs with other values of this parameter. Input should be a python pair like ('-tol', 1e-3) where the first entry is the dictionary key to check and the second entry is the value it should not take. Note the quotes around the key.]::NOT_FILTER:_files" \
  "--save-to-dir[Save figures as pdfs into the specified folder.]::SAVE_TO_DIR:_files" \
  "--ssh-mode[Vastly speed up operation over ssh: don't show plots and use Agg backend.]" \
  "--save-data-to-dir[Also copy trace and info files to the directory.]" \
  "--thesis[Do some modifications to make plots prettier.]" \
  "--debug-mode[Enable debugging mode (run in serial).]" \
  "-n[Number of cores to use]::NCORES:_files" \
  "--ncores[Number of cores to use]::NCORES:_files" \
  "*::args:_files"
