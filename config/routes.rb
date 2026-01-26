SolidqueueDashboard::Engine.routes.draw do
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
  get "jobs/status/pending", to: "jobs#index", defaults: { status: "pending" }, as: :pending_jobs
  get "jobs/status/scheduled", to: "jobs#index", defaults: { status: "scheduled" }, as: :scheduled_jobs
  get "jobs/status/in_progress", to: "jobs#index", defaults: { status: "in_progress" }, as: :in_progress_jobs
  get "jobs/status/failed", to: "jobs#index", defaults: { status: "failed" }, as: :failed_jobs
  get "jobs/status/blocked", to: "jobs#index", defaults: { status: "blocked" }, as: :blocked_jobs
  get "jobs/status/finished", to: "jobs#index", defaults: { status: "finished" }, as: :finished_jobs

  resources :queues, only: [ :index, :show ], param: :name do
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
