# -*- coding: utf-8 -*-
# Create Office Open XML Spreadsheets (xlsx) with safe and full control over cell styles, automatically resized column widths and 3D pie charts.
module Axlsx
  # Package is responsible for managing all the bits and peices that Open Office XML requires to make a valid
  # xlsx document including valdation and serialization.
  class Package

    # The workbook this package will serialize or validate.
    # @attribute
    # @return [Workbook] If no workbook instance has been assigned with this package a new Workbook instance is returned.
    # @raise ArgumentError if workbook parameter is not a Workbook instance.
    # @note As there are multiple ways to instantiate a workbook for the package, 
    #   here are a few examples:
    #     # assign directly during package instanciation
    #     wb = Package.new(:workbook => Workbook.new).workbook
    #
    #     # get a fresh workbook automatically from the package
    #     wb = Pacakge.new().workbook
    #     #     # set the workbook after creating the package
    #     wb = Package.new().workbook = Workbook.new
    attr_accessor :workbook

    # Initializes your package
    #
    # @param [Hash] options A hash that you can use to specify the author and workbook for this package.
    # @option options [String] :author The author of the document
    # @example Package.new :author => 'you!', :workbook => Workbook.new
    def initialize(options={})
      @core, @app = Core.new, App.new
      @core.creator = options[:author] || @core.creator
      yield self if block_given?
    end

    def workbook=(workbook) DataTypeValidator.validate "Package.workbook", Workbook, workbook; @workbook = workbook; end

    def workbook
      @workbook || @workbook = Workbook.new
    end

    # Serialize your workbook to disk as an xlsx document.
    #
    # @param [File] output The file you want to serialize your package to
    # @param [Boolean] confirm_valid Validate the package prior to serialization.
    # @return [Boolean] False if confirm_valid and validation errors exist. True if the package was serialized
    # @note A tremendous amount of effort has gone into ensuring that you cannot create invalid xlsx documents.
    #   confirm_valid should be used in the rare case that you cannot open the serialized file. 
    # @see Package#validate
    # @example
    #   # This is how easy it is to create a valid xlsx file. Of course you might want to add a sheet or two, and maybe some data, styles and charts.
    #   # Take a look at the README for an example of how to do it!
    #   f = File.open('test.xlsx', 'w')
    #   Package.new.serialize(f)
    #
    #   # You will find a file called test.xlsx
    def serialize(output, confirm_valid=false)
      return false unless !confirm_valid || self.validate.empty?
      f = File.new(output, "w")
      Zip::ZipOutputStream.open(f.path) do |zip|
        parts.each{ |part| zip.put_next_entry(part[:entry]); zip.puts(part[:doc]) }
      end
      true
    end

    # Validate all parts of the package against xsd schema. 
    # @return [Array] An array of all validation errors found.
    # @note This gem includes all schema from OfficeOpenXML-XMLSchema-Transitional.zip and OpenPackagingConventions-XMLSchema.zip
    #   as per ECMA-376, Third edition. opc schema require an internet connection to import remote schema from dublin core for dc,
    #   dcterms and xml namespaces. Those remote schema are included in this gem, and the original files have been altered to 
    #   refer to the local versions.
    #
    #   If by chance you are able to creat a package that does not validate it indicates that the internal
    #   validation is not robust enough and needs to be improved. Please report your errors to the gem author.
    # @see http://www.ecma-international.org/publications/standards/Ecma-376.htm
    # @example
    #  # The following will output any error messages found in serialization.
    #  p = Axlsx::Package.new
    #  # ... code to create sheets, charts, styles etc.
    #  p.validate.each { |error| puts error.message }
    def validate
      errors = []
      parts.each { |part| errors.concat validate_single_doc(part[:schema], part[:doc]) }
      errors
    end

    private 

    # The parts of a package
    # @return [Array] An array of hashes that define the entry, document and schema for each part of the package. 
    # @private
    def parts
      @parts = [
       {:entry => RELS_PN, :doc => relationships.to_xml, :schema => RELS_XSD},
       {:entry => CORE_PN, :doc => @core.to_xml, :schema => CORE_XSD},
       {:entry => APP_PN, :doc => @app.to_xml, :schema => APP_XSD},
       {:entry => WORKBOOK_RELS_PN, :doc => workbook.relationships.to_xml, :schema => RELS_XSD},
       {:entry => WORKBOOK_PN, :doc => workbook.to_xml, :schema => SML_XSD},
       {:entry => CONTENT_TYPES_PN, :doc => content_types.to_xml, :schema => CONTENT_TYPES_XSD},
       {:entry => "xl/#{STYLES_PN}", :doc => workbook.styles.to_xml, :schema => SML_XSD}
      ]
      workbook.drawings.each do |drawing|
        @parts << {:entry => "xl/#{drawing.rels_pn}", :doc => drawing.relationships.to_xml, :schema => RELS_XSD}
        @parts << {:entry => "xl/#{drawing.pn}", :doc => drawing.to_xml, :schema => DRAWING_XSD}
      end
        
      workbook.charts.each do |chart|          
        @parts << {:entry => "xl/#{chart.pn}", :doc => chart.to_xml, :schema => DRAWING_XSD}
      end                  
     
      workbook.worksheets.each do |sheet|            
        @parts << {:entry => "xl/#{sheet.rels_pn}", :doc => sheet.relationships.to_xml, :schema => RELS_XSD}
        @parts << {:entry => "xl/#{sheet.pn}", :doc => sheet.to_xml, :schema => SML_XSD}        
      end
      @parts
    end

    # Performs xsd validation for a signle document
    #
    # @param [String] schema path to the xsd schema to be used in validation.
    # @param [String] doc The xml text to be validated
    # @return [Array] An array of all validation errors encountered.
    # @private
    def validate_single_doc(schema, doc)
      schema = Nokogiri::XML::Schema(File.open(schema))
      doc = Nokogiri::XML(doc)

      errors = []
      schema.validate(doc).each do |error|
        errors << error
      end
      errors
    end

    # Appends override objects for drawings, charts, and sheets as they exist in your workbook to the default content types.
    # @return [ContentType]
    # @private
    def content_types
      c_types = base_content_types
      workbook.drawings.each do |drawing|
        c_types << Axlsx::Override.new(:PartName => "/xl/#{drawing.pn}", 
                                       :ContentType => DRAWING_CT)
      end
      workbook.charts.each do |chart|
        c_types << Axlsx::Override.new(:PartName => "/xl/#{chart.pn}", 
                                       :ContentType => CHART_CT)                    
      end
      workbook.worksheets.each do |sheet|
        c_types << Axlsx::Override.new(:PartName => "/xl/#{sheet.pn}", 
                                         :ContentType => WORKSHEET_CT)
      end
      c_types
    end

    # Creates the minimum content types for generating a valid xlsx document.
    # @return [ContentType]
    # @private
    def base_content_types
      c_types = ContentType.new()
      c_types <<  Default.new(:ContentType => RELS_CT, :Extension => RELS_EX)
      c_types <<  Default.new(:Extension => XML_EX, :ContentType => XML_CT)
      c_types << Override.new(:PartName => "/#{APP_PN}", :ContentType => APP_CT)
      c_types << Override.new(:PartName => "/#{CORE_PN}", :ContentType => CORE_CT)
      c_types << Override.new(:PartName => "/xl/#{STYLES_PN}", :ContentType => STYLES_CT)
      c_types << Axlsx::Override.new(:PartName => "/#{WORKBOOK_PN}", :ContentType => WORKBOOK_CT)      
      c_types.lock
      c_types
    end

    # Creates the relationships required for a valid xlsx document
    # @return [Relationships]
    # @private
    def relationships
      rels = Axlsx::Relationships.new
      rels << Relationship.new(WORKBOOK_R, WORKBOOK_PN)
      rels << Relationship.new(CORE_R, CORE_PN)
      rels << Relationship.new(APP_R, APP_PN)
      rels.lock
      rels
    end
  end
end
