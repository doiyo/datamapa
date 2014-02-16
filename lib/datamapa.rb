require 'datamapa/version'
require 'active_record'

module DataMapa
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Declarative methods
    def active_record_class(klass)
      @ar_class = klass
    end

    def creates_model_with(&block)
      @create_model_proc = block
    end

    def semantic_key(key)
      @semantic_key = key
    end

    def simple_attr(attributes)
      @simple_attr = attributes
    end

    def ref_attr(attributes)
      @ref_attr = attributes
    end

    def collection_attr(attributes)
      @collection_attr = attributes
    end

    def composed_of(parts)
      @composed_of = parts
    end

    def composes(parent)
      @composes = parent
    end

    # Public methods
    def o2r(model, ar, options={})
      o2r_attr(model, ar)
      o2r_ref(model, ar)
      o2r_collection(model, ar, options[:include]) if options[:include]
    end

    def r2o(ar, model)
      r2o_simple(ar, model)
      r2o_ref(ar, model)
      r2o_collection(ar, model, @composed_of) if @composed_of
      model
    end

    def find!(id)
      begin
        ar = @ar_class.find(id)
        model_for(ar)
      rescue ActiveRecord::RecordNotFound
        raise DataMapa::RecordNotFoundError
      end
    end

    def where(clause)
      records = @ar_class.where(clause) 
      records.map do |ar|
        model_for(ar)
      end
    end

    def ar_for_saving_model(model)
      if model.id.nil?
        ar = find_ar_with_semantic_key(model) unless @semantic_key.nil?
        ar ||= @ar_class.new
      else
        ar = @ar_class.find(model.id)
      end
      ar
    end

    def create!(model, extras={})
      begin
        attributes = {}

        @simple_attr.each do |attr|
          attributes[:"#{attr.to_s.chomp('?')}"] = model.send(attr)
        end if @simple_attr

        @ref_attr.each_key do |attr|
          ref = model.send(attr)
          attributes[:"#{attr.to_s.chomp('?')}_id"] = ref.id unless ref.nil?
        end if @ref_attr

        extras.each_pair { |key, value| attributes[:"#{key}"] = value }

        ar = @ar_class.create!(attributes)
        model.send(:id=, ar.id)

        @composed_of.each do |parts, mapper|
          mapper.create_parts!(model.send(parts), model.id)
        end if @composed_of
      rescue ActiveRecord::StatementInvalid => e
        raise DataMapa::PersistenceError, e.message
      end
    end

    def update(model, extras={})
      begin
        attributes = {}

        @simple_attr.each do |attr|
          attributes[:"#{attr.to_s.chomp('?')}"] = model.send(attr)
        end if @simple_attr

        @ref_attr.each_key do |attr|
          ref = model.send(attr)
          attributes[:"#{attr.to_s.chomp('?')}_id"] = ref.id unless ref.nil?
        end if @ref_attr

        extras.each_pair { |key, value| attributes[:"#{key}"] = value }

        @ar_class.update(model.id, attributes)

        @composed_of.each do |parts, mapper|
          mapper.update_parts!(model.send(parts), model.id)
        end if @composed_of
      rescue ActiveRecord::StatementInvalid => e
        raise DataMapa::PersistenceError, e.message
      end
    end

    def save!(model, extras={})
      begin
        ar = ar_for_saving_model(model)

        o2r(model, ar)

        extras.each_pair { |key, value| ar.send("#{key}=", value) }
        ar.save!
        model.send(:id=, ar.id)

        @composed_of.each do |parts, mapper|
          mapper.save_parts!(model.send(parts), model.id)
        end if @composed_of
      rescue ActiveRecord::StatementInvalid => e
        raise DataMapa::PersistenceError, e.message
      end
    end

    def save_parts!(parts, parent_id)
      parts.each_with_index do |item, i|
        save!(item, "#{@composes}_id".to_sym => parent_id, :index => i)
      end
    end

    def create_parts!(parts, parent_id)
      parts.each_with_index do |item, i|
        create!(item, "#{@composes}_id".to_sym => parent_id, :index => i)
      end
    end

    def composes_column
      "#{@composes}_id".to_sym
    end

    def update_parts!(parts, parent_id)
      existing_ids = parts.map(&:id).reject { |id| id.nil? }
      @ar_class.where(composes_column => parent_id).where.not(id: existing_ids).delete_all

      parts.each_with_index do |item, i|
        if item.id.nil?
          create!(item, composes_column => parent_id, :index => i)
        else
          update(item, composes_column => parent_id, :index => i)
        end
      end
    end

    def delete!(id)
      @composed_of.each do |part, mapper|
        mapper.delete_children_of(id)
      end

      count = @ar_class.delete(id)
    end

    def model_for(ar)
      model = @create_model_proc.call(ar)
      r2o(ar, model)
      model.id = ar.id
      model
    end

    protected

    def delete_children_of(id)
      @ar_class.delete_all(["#{@composes}_id = ?", id])
    end

    private

    def find_ar_with_semantic_key(model)
      clause = @semantic_key.inject({}) do |memo, attr|
        memo[attr] = model.send(attr)
        memo
      end

      @ar_class.find(clause)
    end

    def r2o_simple(relational, object)
      @simple_attr.each do |attr|
        setter = "#{attr.to_s.chomp('?')}="
        object.send(setter, relational.send(attr))
      end if @simple_attr
    end

    def r2o_ref(ar, object)
      @ref_attr.each do |attr, mapper|
        model = mapper.find!(ar.send("#{attr}_id"))

        setter = "#{attr}="
        object.send(setter, model)
      end if @ref_attr
    end

    def where_clause_for_references_to(id)
      {"#{model_name}_id".to_sym => id}
    end

    def r2o_collection(ar, model, attributes)
      attributes.each do |attr, mapper|
        model_items = mapper.where(where_clause_for_references_to(ar.id))
        model.send("#{attr}=", model_items)
      end
    end

    def model_name
      name.chomp('Mapper').downcase
    end

    def o2r_attr(object, relational)
      @simple_attr.each do |attr|
        relational.send("#{attr.to_s.chomp('?')}=", object.send(attr))
      end if @simple_attr
    end

    def o2r_ref(object, relational)
      @ref_attr.each_key do |attr|
        ref = object.send(attr)
        relational.send("#{attr.to_s.chomp('?')}_id=", ref.id) unless ref.nil?
      end if @ref_attr
    end

    #def o2r_collection(object, relational, attributes)
    #  attributes.each do |attr|
    #    collection = object.send(attr).map do |item| 
    #      @collection_attr[attr].to_ar(item)
    #    end
    #    relational.send("#{attr}=", collection)
    #  end
    #end
  end

  class PersistenceError < StandardError
  end

  class RecordNotFoundError < PersistenceError
  end

  class DuplicateKeyError < PersistenceError
  end
end
