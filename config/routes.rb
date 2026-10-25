JobHarbor::Engine.routes.draw do
  root to: "dashboard#index"

  resources :jobs, only: [ :index, :show ] do
    member do
      post :retry
      delete :discard
    end
    collection do
      post :retry_all
      delete :discard_all
    end
  end

  # Status-scoped job routes
  JobHarbor::JobStatus.all.each do |job_status|
    get "jobs/status/#{job_status.key}", to: "jobs#index", defaults: { status: job_status.key }, as: job_status.route_name
  end

  resources :queues, only: [ :index, :show ], param: :name do
    collection do
      post :pause, action: :pre_pause
    end
    member do
      post :pause
      delete :resume
    end
  end

  resources :workers, only: [ :index ]

  resources :recurring_tasks, only: [ :index, :show ] do
    member do
      post :enqueue_now
    end
  end

  get "search", to: "jobs#search", as: :search
end
