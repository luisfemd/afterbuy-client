defmodule Afterbuy.Filter do
  @moduledoc """
  Afterbuy request filter abstraction
  """

  @type t() ::
          Afterbuy.Filter.AfterbuyUserEmail
          | Afterbuy.Filter.AfterbuyUserId
          | Afterbuy.Filter.Anr
          | Afterbuy.Filter.DateFilter
          | Afterbuy.Filter.DefaultFilter
          | Afterbuy.Filter.Ean
          | Afterbuy.Filter.Level
          | Afterbuy.Filter.OrderId
          | Afterbuy.Filter.Platform
          | Afterbuy.Filter.ProductId
          | Afterbuy.Filter.RangeAnr
          | Afterbuy.Filter.RangeId
          | Afterbuy.Filter.ShopId
          | Afterbuy.Filter.Tag
          | Afterbuy.Filter.UserDefined

  import Saxy.XML

  @doc """
  Returns a filter by passing name and data

      iex> f = Afterbuy.Filter.new(:afterbuy_user_email, %{value: "my-email@mydomain.com"})
      %Afterbuy.Filter.AfterbuyUserEmail{
        name: :afterbuy_user_email,
        value: "my-email@mydomain.com"
      }
  """
  @spec new(Atom.t(), Map.t()) :: __MODULE__.t()
  def new(name, data) when is_map(data) do
    module_name = Inflex.camelize(name)

    [__MODULE__, module_name]
    |> Module.concat()
    |> struct(Map.put(data, :name, name))
  end

  defp get_el("Values", v) when not is_list(v),
    do: get_el("Values", [v])

  defp get_el("Values", v),
    do: Enum.map(v, &get_el("Value", &1))

  @doc false
  defp get_el("Name", v),
    do: element("FilterName", [], Inflex.camelize(v))

  defp get_el("Value", %NaiveDateTime{} = v),
    do:
      element(
        "FilterValue",
        [],
        Timex.format!(v, "{0D}.{0M}.{YYYY} {0h24}:{0m}:{0s}")
      )

  defp get_el("Value", v) when is_tuple(v),
    do: element("FilterValue", [], v)

  defp get_el("Value", v),
    do: element("FilterValue", [], Afterbuy.XML.Encoder.sanitize(v))

  defp get_el(k, v) when is_atom(k),
    do: get_el(Inflex.camelize(k), v)

  defp get_el(k, v),
    do: element(Inflex.camelize(k), [], Afterbuy.XML.Encoder.sanitize(v))

  @doc ~S"""
  `Saxy.Builder` proxy implementation for filter structures.

  This function can be used with:
    * `Afterbuy.Filter.AfterbuyUserEmail`
    * `Afterbuy.Filter.AfterbuyUserId`
    * `Afterbuy.Filter.Anr`
    * `Afterbuy.Filter.DateFilter`
    * `Afterbuy.Filter.DefaultFilter`
    * `Afterbuy.Filter.Ean`
    * `Afterbuy.Filter.Level`
    * `Afterbuy.Filter.OrderId`
    * `Afterbuy.Filter.Platform`
    * `Afterbuy.Filter.ProductId`
    * `Afterbuy.Filter.RangeAnr`
    * `Afterbuy.Filter.RangeId`
    * `Afterbuy.Filter.ShopId`
    * `Afterbuy.Filter.Tag`
    * `Afterbuy.Filter.UserDefinedFlag`
  """
  @spec build(__MODULE__.t()) :: Saxy.XML.content()
  def build(%{__struct__: module} = data) when is_map(data) do
    data_elements =
      data
      |> Map.from_struct()
      |> Enum.filter(fn {k, v} -> not is_nil(v) and k != :name end)
      |> Enum.reduce([], fn {k, v}, acc ->
        acc ++ List.flatten([get_el(k, v)])
      end)

    element("Filter", [], [
      get_el("Name", module.name),
      element("FilterValues", [], data_elements)
    ])
  end

  @doc false
  defmacro __using__({t, f}) do
    quote location: :keep, bind_quoted: [type: t, filter_fields: f] do
      filter_name =
        __MODULE__
        |> Module.split()
        |> List.last()
        |> Inflex.underscore()

      @moduledoc """
      Abstraction for filter name `:#{filter_name}`

      Use with `Afterbuy.Filter.new/2`

          Filter.new(:#{filter_name}, %{...})
      """

      inherit_fields =
        case type do
          :multiple -> [:name, :values]
          :single -> [:name, :value]
          :none -> [:name]
        end

      fields = inherit_fields ++ filter_fields

      @enforce_keys fields
      defstruct fields

      @type t() :: %__MODULE__{}

      @doc """
      Return the filter name tag value. By default, module name
      """
      @spec name :: String.t()
      def name, do: __MODULE__ |> Module.split() |> List.last()

      defimpl Saxy.Builder do
        @doc false
        def build(struct), do: Afterbuy.Filter.build(struct)
      end

      defoverridable name: 0
    end
  end
end
