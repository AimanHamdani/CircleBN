<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ModerateUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->is_admin === true;
    }

    public function rules(): array
    {
        return [
            'action' => ['required', Rule::in(['warning', 'suspend', 'delete'])],
            'feedback' => ['nullable', 'string', 'max:1000'],
            'report_id' => ['nullable', 'integer', 'exists:reports,id'],
        ];
    }
}
