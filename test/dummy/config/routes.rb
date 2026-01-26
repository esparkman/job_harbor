Rails.application.routes.draw do
  mount SolidqueueDashboard::Engine => "/solidqueue_dashboard"
end
