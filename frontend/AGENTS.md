# Frontend rules

Frontend chooses modes and displays view state; it must not mutate
`BattleSimulation` directly or define combat rules. Concrete roster knowledge is
permitted here during the current migration, but must not leak into generic core.
Use services/catalog APIs introduced by their task packet rather than new direct
character preloads.
