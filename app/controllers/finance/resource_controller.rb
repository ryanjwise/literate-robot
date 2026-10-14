module Finance
  # Plain JSON CRUD. Subclasses define `model` and `permitted`.
  class ResourceController < BaseController
    def index
      render json: scope.order(:id)
    end

    def show
      render json: record
    end

    def create
      render json: model.create!(permitted), status: :created
    end

    def update
      record.update!(permitted)
      render json: record
    end

    def destroy
      if record.destroy
        head :no_content
      else
        render json: { errors: record.errors }, status: :unprocessable_content
      end
    end

    private

    def scope = model.all
    def record = @record ||= model.find(params[:id])
  end
end
