class RefusedNewsletterJob < NewsletterJob
  before_enqueue { throw :abort }
end
