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

  # Queue names are free text; generation escapes them and format: false keeps dots in the name.
  resources :queues, only: [ :index, :show ], param: :name, constraints: { name: /.+/ }, format: false do
    member do
      post :pause
      delete :resume
    end
  end

  namespace :queues do
    resources :pauses, only: :create, format: false
  end

  resources :workers, only: [ :index ]

  resources :recurring_tasks, only: [ :index, :show ] do
    member do
      post :enqueue_now
    end
  end

  get "search", to: "jobs#search", as: :search
end
