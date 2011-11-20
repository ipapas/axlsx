module Axlsx
  # The Marker class defines a point in the worksheet that drawing anchors attach to.
  # @note The recommended way to manage markers is Worksheet#add_chart Markers are created for a two cell anchor based on the :start and :end options.
  # @see Worksheet#add_chart
  class Marker

    # The column this marker anchors to
    # @return [Integer]
    attr_accessor :col

    # The offset distance from this marker's column
    # @return [Integer]
    attr_accessor :colOff

    # The row this marker anchors to
    # @return [Integer]
    attr_accessor :row

    # The offset distance from this marker's row
    # @return [Integer]
    attr_accessor :rowOff

    # Creates a new Marker object
    # @option options [Integer] col
    # @option options [Integer] colOff
    # @option options [Integer] row
    # @option options [Integer] rowOff
    def initialize(options={})
      @col, @colOff, @row, @rowOff = 0, 0, 0, 0
      options.each do |o|
        self.send("#{o[0]}=", o[1]) if self.respond_to? o[0]
      end      
    end
    
    def col=(v) Axlsx::validate_unsigned_int v; @col = v end
    def colOff=(v) Axlsx::validate_int v; @colOff = v end
    def row=(v) Axlsx::validate_unsigned_int v; @row = v end
    def rowOff=(v) Axlsx::validate_int v; @rowOff = v end

    # shortcut to set the column, row position for this marker
    # @param col the column for the marker
    # @param row the row of the marker
    def coord(col, row)
      self.col = col
      self.row = row
    end
    # Serializes the marker
    # @param [Nokogiri::XML::Builder] xml The document builder instance this objects xml will be added to.
    # @return [String]
    def to_xml(xml)
      [:col, :colOff, :row, :rowOff].each do |k|
        xml.send("xdr:#{k.to_s}", self.send(k))
      end      
    end
  end

end