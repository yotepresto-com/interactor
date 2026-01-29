# frozen_string_literal: true

module Interactor
  describe Validations do
    let(:interactor_class) do
      Class.new do
        include Interactor

        requires :email, :password

        def call
          context.user = "authenticated"
        end
      end
    end

    describe ".requires" do
      it "defines required attributes" do
        expect(interactor_class.required_attributes).to contain_exactly(:email, :password)
      end

      it "allows multiple calls to requires" do
        interactor_class.requires(:name)
        expect(interactor_class.required_attributes).to contain_exactly(:email, :password, :name)
      end

      it "delegates required attributes to context" do
        interactor = interactor_class.new(email: "test@example.com", password: "secret")
        expect(interactor.email).to eq("test@example.com")
        expect(interactor.password).to eq("secret")
      end
    end

    describe "#validate_required_attributes" do
      context "when all required attributes are present" do
        it "does not fail the context" do
          result = interactor_class.call(email: "test@example.com", password: "secret")
          expect(result).to be_a_success
          expect(result.user).to eq("authenticated")
        end
      end

      context "when a required attribute is missing" do
        it "raises ArgumentError" do
          expect {
            interactor_class.call(email: "test@example.com")
          }.to raise_error(ArgumentError, "Required attribute password is missing")
        end
      end

      context "when multiple required attributes are missing" do
        it "raises ArgumentError for the first missing attribute" do
          expect {
            interactor_class.call({})
          }.to raise_error(ArgumentError, "Required attribute email is missing")
        end
      end

      context "when required attribute is nil" do
        it "raises ArgumentError" do
          expect {
            interactor_class.call(email: nil, password: "secret")
          }.to raise_error(ArgumentError, "Required attribute email is missing")
        end
      end

      context "when no required attributes are defined" do
        let(:simple_interactor) do
          Class.new do
            include Interactor

            def call
              context.result = "success"
            end
          end
        end

        it "does not fail the context" do
          result = simple_interactor.call
          expect(result).to be_a_success
          expect(result.result).to eq("success")
        end
      end
    end
  end
end
