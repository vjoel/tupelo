class Tupelo::Client
  module Api
    TUPELO_SUBSPACE_TAG = "tupelo subspace".freeze

    def tupelo_subspace_tag
      @tupelo_subspace_tag ||=
        symbolize_keys ? TUPELO_SUBSPACE_TAG.to_sym : TUPELO_SUBSPACE_TAG
    end

    def tupelo_meta_key
      @tupelo_meta_key ||= symbolize_keys ? :__tupelo__ : "__tupelo__".freeze
    end

    def define_subspace tag, template, addr: nil
      metatuple = {
        tupelo_meta_key => "subspace",
        tag:        tag,
        template:   PortableObjectTemplate.spec_from(template),
        addr:       addr
      }
      write_wait metatuple
    end

    # call this just once at start of first client (it's optional to
    # preserve behavior of non-subspace-aware code); this is done automatically
    # in the app framework
    def use_subspaces!
      return if find_subspace_by_tag(TUPELO_SUBSPACE_TAG)
      define_subspace(TUPELO_SUBSPACE_TAG, {
        tupelo_meta_key => "subspace",
        tag:        nil,
        template:   nil,
        addr:       nil
      })
    end

    def subspace tag
      tag = tag.to_s
      find_subspace_by_tag(tag) or begin
        if subscribed_tags.include? tag
          read tupelo_meta_key => "subspace",
            tag:      tag,
            template: nil,
            addr:     nil
          find_subspace_by_tag tag
        end
      end
      ## this impl will not be safe with dynamic subspaces
    end

    def find_subspace_by_tag tag
      worker.find_subspace_by_tag tag
    end
  end
end
