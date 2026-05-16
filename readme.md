- [ ] pridat description ze transitive ma jednu major strategy ktera je NE
- [ ] chybi mi oboje matching pennies experimenty vyplocene 
- [x] ~~chybi rps_9_10s avg plot~~ nechybi jsem kkt


- [x] `Game.jl`: remove `queries`
- [x] `Game.jl` remove `zero_sum::Bool` parameter 
- [x] remove `special_type` default bcs it is required 
- [ ] rename `special_type` to `game_type` 
- [x] mozna ten parametr co volam vzdycky navic u `run_and_collect()` je game-wise dost zbytecny protoze to vzdycky prepise ta druha lol no nevermind - *edit: tak neni ale tim padem teda absolutne netusim k cemu je to dobry* - je to k legende! 
- [x] ~~dopsat do tabulky porovnani pro rps_k, symm atd~~ prcat  
- [x] actually i can compare GW and FP by iterations, sam for RM, PRM...  
- [x] rm neni rm+ 

- [ ] IMPLEMENT LAZY PAYOFFS 

- [x] ~~aktualne i rm je rm+ ---> fix required~~

- [x] ehmm mozna ten problem s malou konvergenci random-zero-sum mozna nebyl v tom algoritmu ale v tom ze to actually generovalo non-zero-sum - ne tak neni, symm to neni, wtf - large-scake hry funguji 


- [x] check v kodu: je v `history` ulozena vzdy average strategy? nebo pocitam exploitability z tech last used? protoze last used se pomoci nasobeni posbira do te average, ale ted nevim jestli jsem to tam udelala spravne 
- [x] udelat kod tak, abych pak extra nemusela dodavat JuMP, GLPK, Ipopt, CSV, DataFrames - DONE 
- [x] cemu nerozumim - u `compute_exploitability()` porovnavam s best response? co se tam deje? """ per-iteration exploitability of stored strategies vs best responses """ - nemam to treba porovnavat s minimaxem?? - SOLVED 

- [x]vysvetlit cutpointy 

- [x] asi nepotrbuju vracet oboje `best_w`, `best_phi`, staci jen `best_w`---> zmenit occurences vsude!! - *edit: nicemu to nevadi, nebudu menit, aspon je to nazorne* 

- [x] i am NOT calling `potential_func()`?? what the fuck? 
- [x] blotto implementovany neni (ale bude soon) - DONE 


_______________________ RUN IT ___________________________
```bash
julia --project=@ example.jl 
```
__________________________________________________________

OVERVIEW:  
- `example.jl`: the entry point / it activates the local projects, loads the greedy-weights and double-oracle modules, then compares both algorithms on a random zero-sum game and a morra and saves combined exploitability plot to `media/COMBINED/...`
- `greedy-weights/Game.jl`: game framework defined, special game cases implemented, else it builds a payoff matrix (random or special case such as `morra_k` etc) 
- `greedy-weights/RefretMinimization.jl` - Greedy Regret Minimization algorithm implemented here. `external_regret()` runs the loop, keeps regret/time traces, records strategy history. `compute_exploitability()` can turn that history into explo once the run finishes 

- `compute_next_moves()` (probabilistic choice via blackwell approachability) and `find_optimal_weight()` are where greedy weights differ from plain regret matching
- benchmark against a true solution: `MinMaxSolver.minmax_solution(game)` uses GLPK to solve the 2-player zero-sum LP 



then for comparison  
- Double Oracle (stolen): 
    - `double-oracle/MatrixOracle.jl` and `double-oracle/matrix_oracle.jl`: create an oracle from `(A,B)` payoff slices and call `until_eps` to iterate until a time limit or target `\eps` is hit





zadani platne do 09/2026  
asi bych chtela statnicovat v lete -> zadost obsahujici posun terminu odevzdani (tj kveten)  


based on the [paper](https://arxiv.org/abs/2204.04826)  
implementation inspo from [the official repository](https://github.com/hughbzhang/greedy-weights) for the paper 

kod v `/double-oracle/...` neni muj (ukraden a drobne upraven, protoze nemam licenci na *`Gurobi Optimizer`*), jenom to potrebuju rozbehnout kvuli porovnavani  
autor [zde](https://github.com/votroto/MatrixOracle.jl/tree/main) 


____





