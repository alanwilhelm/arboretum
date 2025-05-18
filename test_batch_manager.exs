alias Arboretum.BatchManager
alias Arboretum.Agents.Agent

agent = %Agent{
  llm_config: %{"model" => "gpt-4"}  
}

IO.inspect agent.llm_config, label: "llm_config"
IO.inspect Map.get(agent.llm_config, "model"), label: "model"

result = BatchManager.get_rate_limit_bucket_for_agent(agent)
IO.inspect result, label: "result"
EOF < /dev/null