using Microsoft.Data.SqlClient;
using System;

namespace HuyPhanApi.Extensions  // ← Dùng namespace riêng để tránh trùng
{
    public static class SqlDataReaderExtensions
{
    public static string GetSafeString(this SqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? "" : reader.GetString(ordinal).Trim();
    }

    public static decimal GetSafeDecimal(this SqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? 0m : reader.GetDecimal(ordinal);
    }
}
}