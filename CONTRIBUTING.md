# Contributing

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-pattern`)
3. Commit changes (`git commit -m 'Add new pattern'`)
4. Push to branch (`git push origin feature/new-pattern`)
5. Open a Pull Request

## Guidelines

- Follow existing code style
- Include README.md for each pattern
- Test Terraform with `terraform validate` and `terraform plan`
- Update root README.md if adding new patterns

## Pattern Structure

```
pattern-name/
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
└── lambda/ (if applicable)
```
